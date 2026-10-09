# @path: ~/projects/configs/nix-config/home/core/exp/sys/compat/appimage-run.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::compat::appimage-run
# - appimage-run: used run appimage

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{

  # T3.2: linux-only package(s) — skipped on the darwin closure.

  home.packages = lib.mkIf shared.caps.linux-family (with pkgs; [ appimage-run ]);

}
