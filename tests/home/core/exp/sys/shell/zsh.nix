# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/shell/zsh.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::shell::zsh
# @source: home/core/exp/sys/shell/zsh.nix
#
# Mirrors production config:
#   programs.zsh.enable = true
#   enableCompletion = true
#   autocd = true
#   defaultKeymap = "emacs"
#   autosuggestion.enable = true
#   syntaxHighlighting.enable = true
#   historySubstringSearch.enable = true
#   history.size = 50000
#   shellAliases: vi = nvim, etc.
#   plugins: fzf-tab

{ pkgs, lib, ... }:
let
  testUser = "zshtest";
in
{
  name = "home_core_exp_sys_shell_zsh";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    programs.zsh.enable = true;

    users = {
      mutableUsers    = false;
      defaultUserShell = pkgs.zsh;
      users.${testUser} = {
        isNormalUser    = true;
        useDefaultShell = true;
        initialPassword = "test";
      };
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("zsh: binary present"):
        w = machine.succeed("which zsh").strip()
        assert "zsh" in w, f"zsh not found: {w}"

    with subtest("zsh: version reportable"):
        ver = machine.succeed("zsh --version 2>&1").strip()
        print(f"zsh: {ver}")
        assert "zsh" in ver.lower(), f"Unexpected zsh output: {ver}"

    with subtest("zsh: executes a command"):
        out = machine.succeed("zsh -c 'echo zsh_ok'").strip()
        assert out == "zsh_ok", f"zsh exec failed: {out}"

    with subtest("zsh: default shell for ${testUser}"):
        shell = machine.succeed(
            "getent passwd ${testUser} | cut -d: -f7"
        ).strip()
        print(f"shell: {shell}")
        assert "zsh" in shell, f"Default shell not zsh: {shell}"

    with subtest("zsh: compinit loadable"):
        out = machine.succeed(
            "zsh -c 'autoload -U compinit && echo compinit_ok' 2>&1"
        ).strip()
        assert "compinit_ok" in out, f"compinit failed: {out}"
  '';
}
