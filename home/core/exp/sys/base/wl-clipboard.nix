# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/wl-clipboard.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::wl-clipboard

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

  home.packages = lib.mkIf shared.caps.linux-family (
    with pkgs;
    [
      wl-clipboard # command-line

    ]
  );
}
