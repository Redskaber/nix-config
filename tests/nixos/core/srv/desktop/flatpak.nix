# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/desktop/flatpak.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::srv::desktop::flatpak
# @source: nixos/core/srv/desktop/flatpak.nix

{ shared, pkgs, ... }:
{
  name = "nixos_core_srv_desktop_flatpak";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 768;
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      xdgOpenUsePortal = true;

      config = {
        common.default = [ "gtk" ];
        ${shared.window-manager.tag}.default = shared.window-manager.value.portal.value.default;
      };

      extraPortals = shared.window-manager.value.portal.value.extraPortals pkgs;

    };
    services.flatpak.enable = true;
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
