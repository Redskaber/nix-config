# @path: ~/projects/configs/nix-config/lib/shared/default.nix
# @author: redskaber
# @datetime: 2026-03-06
# @discription: lib::shared::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - shared configurations loader design
# - checker:
#   - enum::platform
#   - enum::arch
#   - enum::drive
#   - enum::window-manager

{ nixpkgs, inputs, scfpath ? ../../shared.nix, ... }:
let
  jokerShared = import ./loader.nix { inherit nixpkgs inputs scfpath; };
  core = import ./core.nix { inherit nixpkgs; };

  # checker
  _vaild_paltform       = core.fn-get_platform_name jokerShared.paltform;
  _vaild_arch           = core.fn-get_arch_name jokerShared.arch;
  _vaild_drive          = core.fn-get_drive_name jokerShared.drive;
  _vaild_window_manager = core.fn-get_wm_name jokerShared.window-manager;

  # fix-pkgs
  pkgsAttrs = if jokerShared ? nixpkgs then
    { system = jokerShared.arch.second; } // jokerShared.nixpkgs
  else
    { system = jokerShared.arch.second; };
  core_pkgs = { pkgs = import nixpkgs pkgsAttrs; };
  shared = core // core_pkgs;

  # reload
  userShared = import scfpath { inherit shared inputs; };
  fullShared = shared // userShared // { _user_shared = userShared; };

in fullShared


