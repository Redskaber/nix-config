# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/git.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::git
# @source: home/core/exp/sys/base/git.nix
#
# Mirrors production:
#   programs.git.enable = true
#   settings.init.defaultBranch = shared.git.defaultBranch  ("main")
#   settings.user.name = shared.git.name                    ("redskaber")
#   settings.user.email = shared.git.email
#   settings.pull.rebase = true
#   programs.delta.enable = true  (diff pager)
#   programs.lazygit.enable = true

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_git";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ git delta lazygit ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("git: binary present"):
        ver = machine.succeed("git --version").strip()
        print(f"git: {ver}")
        assert "git" in ver

    with subtest("git: init + commit lifecycle"):
        machine.succeed("""
          set -e
          tmp=$(mktemp -d)
          cd "$tmp"
          git init
          git config user.email "ci@test.local"
          git config user.name  "CI Tester"
          git config init.defaultBranch main
          echo "hello" > README.md
          git add README.md
          git commit -m "init"
          git log --oneline | grep -q "init"
        """)

    with subtest("git: default branch is main"):
        out = machine.succeed("""
          tmp=$(mktemp -d)
          cd "$tmp"
          git -c init.defaultBranch=main init >&2
          git symbolic-ref --short HEAD
        """).strip()
        assert out == "main", f"Expected 'main', got: {out}"

    with subtest("git: delta binary present"):
        w = machine.succeed("which delta").strip()
        assert "delta" in w, f"delta not found: {w}"

    with subtest("git: lazygit binary present"):
        w = machine.succeed("which lazygit").strip()
        assert "lazygit" in w, f"lazygit not found: {w}"
  '';
}
