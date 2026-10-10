# @path: ~/projects/configs/nix-config/home/core/base/wsl.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: home::core::base::wsl — WSL user-space specialisation (T7.1)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# The user-domain half of the WSL specialisation, gated on the
# capability fact (shared.caps.wsl, T4.0) — ONE place, consumed by
# every wsl-capable host:
#
#   hosts/wsl        platform.wsl          (standalone HM, non-NixOS)
#   hosts/nixos-wsl  platform.nixos-wsl    (the fifth system form, T7.1)
#
# Before T7.1 this surface lived inline in
# platform/wsl/home/x86_64-linux.nix — correct for the one host that
# had caps.wsl, structurally unreachable for a second one. The
# extraction keeps the values byte-equal (the standalone-wsl HM
# closure must not move); what changed is the ADDRESS: caps-gated
# shared-tree module, the same shape the system side has used since
# T3.1 (platform/nixos/core/base/wsl.nix keeps the system-domain
# deltas — the two files are the boundary, read together).
#
# What belongs HERE (user space): wslview routing, WSLENV crossing,
# USERPROFILE normalisation. What does NOT: wsl.conf, systemd
# hosting, binfmt — NixOS-WSL interpreter owns those (and a
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

    # Route "open link" to the Windows side: wslview(1) from wslu
    # forwards URLs/files to the Windows default handler. (xdg.portal
    # itself stays managed by home/core/base/portal.nix — the
    # none-portal strategy it resolves to already installs zero portal
    # backends, so there is nothing to fight over here.)
    xdg.enable = true;
    home.sessionVariables.BROWSER = "wslview";
  };
}
