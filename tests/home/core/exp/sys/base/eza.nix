# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/eza.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::eza
# @source: home/core/exp/sys/base/eza.nix
#
# Mirrors production:
#   home.packages = [eza]
#   shellAliases: ls = "eza --icons=always", ll, la, lt

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_eza";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ eza ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("eza: binary present"):
        w = machine.succeed("which eza").strip()
        assert "eza" in w, f"eza not found: {w}"

    with subtest("eza: version reportable"):
        ver = machine.succeed("eza --version 2>&1 | head -1").strip()
        print(f"eza: {ver}")
        assert "eza" in ver.lower() or ver != ""

    with subtest("eza: lists /tmp"):
        out = machine.succeed("eza /tmp 2>&1").strip()
        print(f"eza /tmp: {out}")

    with subtest("eza: tree mode works"):
        machine.succeed("mkdir -p /tmp/eza_tree/sub")
        out = machine.succeed("eza --tree /tmp/eza_tree 2>&1").strip()
        assert "sub" in out, f"eza tree missing sub: {out}"
  '';
}
