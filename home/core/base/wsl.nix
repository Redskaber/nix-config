# @path: ~/projects/configs/nix-config/home/core/base/wsl.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: home::core::base::wsl — WSL user-space specialisation
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# The user-domain half of the WSL specialisation, gated on the
# capability fact (shared.caps.wsl) — ONE shared-tree address,
# consumed by every wsl-capable host:
#
#   hosts/wsl        platform.wsl        (standalone HM, non-NixOS)
#   hosts/nixos-wsl  platform.nixos-wsl  (NixOS system form)
#
# The system-domain deltas live in
# platform/nixos/system/core/base/wsl.nix — the two files are the
# boundary, read together.
#
# What belongs HERE (user space): wslview routing, WSLENV crossing,
# USERPROFILE normalisation. What does NOT: wsl.conf, systemd
# hosting, binfmt — the NixOS-WSL interpreter owns those (and a
# non-NixOS WSL distro owns its own).

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf shared.caps.wsl {
    # wslview = in-tree shim (pkgs/wslview) — wslu was removed upstream.
    home.packages = [ pkgs.wslview ];

    home.sessionVariables = {
      # Vars allowed to cross into Windows processes launched from WSL.
      # "/u" = share as-is (no path translation needed for these).
      WSLENV = lib.concatStringsSep ":" [
        "WAYLAND_DISPLAY/u"
        "XDG_SESSION_TYPE/u"
      ];
      # WSL injects USERPROFILE (a /mnt/c/... path) — normalise for tools
      # that assume it points at a usable home.
      USERPROFILE = "\${HOME}";
    };

    # Route "open link" to the Windows side: wslview(1) forwards
    # URLs/files to the Windows default handler. xdg.portal stays with
    # home/core/base/portal.nix — its none strategy installs zero
    # backends, nothing to fight over here.
    xdg.enable = true;
    home.sessionVariables.BROWSER = "wslview";
  };
}
