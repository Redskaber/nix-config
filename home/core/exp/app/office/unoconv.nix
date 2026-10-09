# @path: ~/projects/configs/nix-config/home/core/exp/app/office/unoconv.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::office::unoconv
# - Convert between any document format supported by LibreOffice/OpenOffice

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
  home.packages = lib.mkIf shared.caps.linux-family (with pkgs; [ unoconv ]);

}
