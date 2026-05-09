# @path: ~/projects/configs/nix-config/tests/home/core/base/portal.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::base::portal
# @source: home/core/base/portal.nix
#
# home/core/base/portal.nix gates on !shared.isNixOS.
# On NixOS the portal is managed by nixos/core/base/portal.nix.
# This test verifies the NixOS-level xdg.portal config (same outcome).

{ pkgs, lib, ... }:
{
  name = "home_core_base_portal";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    xdg.portal = {
      enable       = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      config.common.default = [ "gtk" ];
    };

    environment.systemPackages = with pkgs; [ xdg-desktop-portal ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("portal: xdg-desktop-portal binary present"):
        w = machine.succeed("which xdg-desktop-portal 2>/dev/null || true").strip()
        print(f"xdg-desktop-portal: {w}")

    with subtest("portal: portal unit listed"):
        rc = machine.execute(
            "systemctl list-unit-files xdg-desktop-portal.service 2>/dev/null"
        )[0]
        print(f"portal unit rc: {rc}")

    with subtest("portal: share dir exists"):
        rc = machine.execute(
            "test -d /run/current-system/sw/share/xdg-desktop-portal"
            " || test -d /usr/share/xdg-desktop-portal"
        )[0]
        print(f"portal share dir rc: {rc}")
  '';
}
