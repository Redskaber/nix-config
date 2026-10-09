# @path: ~/projects/configs/nix-config/platform/wsl/home/x86_64-linux.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: platform::wsl::home::x86_64-linux — WSL2 real specialisation (T3.1/T5.11)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# The x86_64-linux arch row of platform/wsl' user domain (grammar v3:
# arch rows live INSIDE home/ — see platform/nixos/home/
# x86_64-linux.nix for the full row contract).
#
# WAS a byte-for-byte copy of platform/linux (review finding); now a real
# fork. What stays from generic-Linux: nixGL (WSLg/directx offload for
# GUI apps) and the home core/env imports. What WSL adds on top:
#
#   ── Windows interop (user space side) ─────────────────────────────
#   * wslu: wslview/clip.exe/explorer.exe wrappers — xdg-open points at
#     wslview so "open file" lands in the Windows shell, not a missing
#     browser inside WSL.
#   * WSLENV session variable: white-lists the vars that cross the WSL
#     boundary into Windows processes (wayland display handoff etc.).
#   * HOME fixups: WSL sets USERPROFILE to a Windows path; keep tools
#     that expect it happy by re-exporting from WSL's own view.
#
#   ── What this file deliberately does NOT do ───────────────────────
#   System-level WSL facts (wsl.conf, systemd-in-WSL, binfmt registration
#     for .exe, appendWindowsPath) belong to the NixOS layer and live in
#     platform/nixos/core/base/wsl.nix — kept separate so a WSL host running a
#     non-Nix distro (Ubuntu + home-manager) still evaluates this file.
#
# The wm import is unconditional (T3.1/T3.2 Null-Object pattern): the
# window-manager strategy routes to home/wm/none on console hosts.

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  # linux non-nixos environment inject
  targets.genericLinux = {
    enable = true;
    nixGL = {
      packages = inputs.nixgl.packages;
      defaultWrapper = "mesa";
      offloadWrapper = "mesaPrime";
    };
  };

  home = {
    username = shared.user.username;
    homeDirectory = shared.homeDir;
    stateVersion = shared.version.value.stateVersion;
  };
  programs.home-manager.enable = true;

  # You can import other home-manager modules here
  imports = [
    # If you import other home-manager modules from other flakes (such as nix-colors):
    # You can also split up your configuration and import pieces of it here:
    ../../../home/core
    ../../../home/env
    ../../../home/wm
    # devShells: import dev/lang.nix from flake.nix
  ];

  # used user custom inxpkgs
  nixpkgs = shared.nixpkgs;

  # ── WSL2 user-space specialisation (T3.1) ─────────────────────────
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

  # Route "open link" to the Windows side: wslview(1) from wslu forwards
  # URLs/files to the Windows default handler. (xdg.portal itself stays
  # managed by home/core/base/portal.nix — the none-portal strategy it
  # resolves to already installs zero portal backends, so there is
  # nothing to fight over here.)
  xdg.enable = true;
  home.sessionVariables.BROWSER = "wslview";

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

}
