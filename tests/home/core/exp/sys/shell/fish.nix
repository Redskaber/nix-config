# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/shell/fish.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::shell::fish
# @source: home/core/exp/sys/shell/fish.nix
#
# Mirrors production config:
#   programs.fish.enable = true
#   preferAbbrs = true
#   generateCompletions = true
#   plugins: autopair, fzf-fish
#   shellAliases: vi = nvim, etc.

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_shell_fish";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    programs.fish.enable = true;
    environment.systemPackages = with pkgs; [ fish ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("fish: binary present"):
        w = machine.succeed("which fish").strip()
        assert "fish" in w, f"fish not found: {w}"

    with subtest("fish: version reportable"):
        ver = machine.succeed("fish --version 2>&1").strip()
        print(f"fish: {ver}")
        assert "fish" in ver.lower(), f"Unexpected fish output: {ver}"

    with subtest("fish: executes a command"):
        out = machine.succeed("fish -c 'echo fish_ok'").strip()
        assert out == "fish_ok", f"fish exec failed: {out}"

    with subtest("fish: can set and read variable"):
        out = machine.succeed(
            "fish -c 'set -l myvar hello_fish; echo $myvar'"
        ).strip()
        assert out == "hello_fish", f"fish variable failed: {out}"
  '';
}
