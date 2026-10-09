# @path: ~/projects/configs/nix-config/home/core/exp/app/video/kazumi.nix
# @author: redskaber
# @datetime: 2026-05-15
# @description: home::core::exp::app::video::kazumi

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
  home.packages = lib.mkIf shared.caps.linux-family (with shared.upkgs; [ kazumi ]);

}
