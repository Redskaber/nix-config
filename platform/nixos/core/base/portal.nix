# @path: ~/projects/configs/nix-config/platform/nixos/core/base/portal.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: platform::nixos::core::base::portal

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  # Portal mediation is a desktop-session capability (T7.2): the
  # window-manager enum's `desktop-session` bit answers "does a real
  # desktop session exist here" — and xdg-desktop-portal only means
  # something inside one (file dialogs, open-with, screenshots are
  # session interactions). Console forms — the vm server shape since
  # this task, the nixos-wsl WSL form since T7.1 — legally subtract
  # the whole stack through this gate; desktop hosts are untouched.
  # The gate reads the resolved fact (the enum row's payload), never
  # a raw tag comparison — the T4.0 law. The home tree's counterpart
  # (home/core/base/portal.nix) already routed console forms to the
  # none strategy's zero backends; this gate completes that design on
  # the system side (the service itself was still riding console
  # closures — wlr portal + the base xdg-desktop-portal on a WSL
  # distro where WSLg/Windows owns mediation).
  config = lib.mkIf shared.window-manager.value.desktop-session {
    # base(wayland)
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
  };
}
