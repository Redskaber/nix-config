# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/desktop/flatpak.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::srv::desktop::flatpak
# @source: nixos/core/srv/desktop/flatpak.nix

{ pkgs, lib, ... }:
{
  name = "nixos_core_srv_desktop_flatpak";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 768;
    services.flatpak.enable = true;
    xdg.portal = {
      enable       = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = [ "gtk" ];
    };
    environment.systemPackages = with pkgs; [ flatpak ];

  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("flatpak: binary present and version reported"):
        ver = machine.succeed("flatpak --version 2>&1").strip()
        print(f"flatpak version: {ver}")
        assert "Flatpak" in ver, f"flatpak not found or wrong output: {ver}"
  '';
}
