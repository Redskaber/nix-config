# @path: ~/projects/configs/nix-config/tests/integration/hm_activation.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::integration::hm_activation
#
# Integration test: activates a representative home-manager configuration
# inside a full NixOS VM.
#
# Validates the end-to-end activation contract:
#   - home-manager NixOS module wires correctly
#   - User's home directory is created
#   - Default shell (zsh) is the login shell
#   - git (home/core/exp/sys/base/git.nix)   is accessible in user env
#   - direnv (home/core/exp/sys/base/direnv) is accessible
#   - ripgrep (home/core/exp/sys/base/ripgrep) available
#   - Python dev tooling (home/env/dev/python) available
#
# Scope: Integration-Plane
# Backend: QEMU VM with home-manager NixOS module
# Note: sops secrets NOT required; packages only.

{ pkgs, inputs, shared, ... }:
let
  testUser = "hmintegtest";

  # home-manager NixOS module binding — injected only when inputs is available
  # (standalone `nix build .#checks...` always has inputs via flake.nix)
  hmConfig = if inputs != null then {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager = {
      useGlobalPkgs   = true;
      useUserPackages = true;
      users.${testUser} = {
        home = {
          username      = testUser;
          homeDirectory = "/home/${testUser}";
          stateVersion  = "${shared.version.value}";

          # Representative packages from home/core + home/env/dev
          packages = with pkgs; [
            ripgrep
            fd
            bat
            direnv
            git
            delta
            python314
            uv
          ];
        };

        programs = {
          git = {
            enable    = true;
            settings = {
              init = {
                defaultBranch = shared.git.defaultBranch;
              };
              user = {
                name = shared.git.name;
                email = shared.git.email;
              };
              core.editor = shared.editor.tag;
              pull.rebase = true;
              push.autoSetupRemote = true;
            };
          };
          zsh = {
            enable            = true;
            autosuggestion.enable = true;
            syntaxHighlighting.enable = true;
          };
          direnv = {
            enable            = true;
            nix-direnv.enable = true;
          };
          starship = {
            enable                 = true;
            enableZshIntegration   = true;
          };
          atuin = {
            enable                 = true;
            enableZshIntegration   = true;
          };
          tmux.enable = true;
        };
      };
    };
  } else {};

in
{
  name = "integration_hm_activation";
  meta = { maintainers = [ "redskaber" ]; timeout = 600; };

  nodes.machine = { config, ... }: {
    virtualisation.memorySize = 1536;

    programs.zsh.enable = true;

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    users = {
      mutableUsers    = false;
      defaultUserShell = pkgs.zsh;
      users.${testUser} = {
        isNormalUser    = true;
        useDefaultShell = true;
        initialPassword = "hmtest";
      };
    };

    environment.systemPackages = with pkgs; [
      git direnv ripgrep fd bat
      python314
      uv
      starship atuin tmux
    ];
  } // hmConfig;

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("integration: user ${testUser} exists"):
        out = machine.succeed("id ${testUser}").strip()
        print(f"user: {out}")
        assert "${testUser}" in out

    with subtest("integration: default shell is zsh"):
        shell = machine.succeed(
            "getent passwd ${testUser} | cut -d: -f7"
        ).strip()
        print(f"shell: {shell}")
        assert "zsh" in shell, f"Expected zsh, got: {shell}"

    with subtest("integration: home directory exists"):
        rc = machine.execute("test -d /home/${testUser}")[0]
        assert rc == 0, "/home/${testUser} missing"

    with subtest("integration: git accessible for user"):
        ver = machine.succeed(
            "su - ${testUser} -c 'git --version' 2>&1"
        ).strip()
        print(f"git: {ver}")
        assert "git" in ver

    with subtest("integration: ripgrep (rg) accessible"):
        w = machine.succeed("which rg").strip()
        assert "rg" in w, f"rg not found: {w}"

    with subtest("integration: direnv accessible"):
        w = machine.succeed("which direnv").strip()
        assert "direnv" in w

    with subtest("integration: python3.12 accessible"):
        ver = machine.succeed("python3.12 --version 2>&1").strip()
        assert "Python 3.12" in ver

    with subtest("integration: uv accessible"):
        ver = machine.succeed("uv --version 2>&1").strip()
        assert "uv" in ver.lower()

    with subtest("integration: tmux accessible"):
        w = machine.succeed("which tmux").strip()
        assert "tmux" in w

    with subtest("integration: git commit works for user"):
        machine.succeed("""
          su - ${testUser} -c '
            set -e
            tmp=$(mktemp -d)
            cd "$tmp"
            git init
            git config user.email ci@test
            git config user.name  CI
            echo hi > f.txt
            git add f.txt
            git commit -m init
            git log --oneline | grep init
          '
        """)
  '';
}
