# @path: ~/projects/configs/nix-config/home/core/exp/app/office/wps.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::office::wps
# - Office suite, formerly Kingsoft Office

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
# wps-office-cn is a Linux deb repack — an installable-but-dead blob on
# non-linux-family hosts. The lean app-set row keeps this tree for its
# cross-platform siblings (pandoc, poppler), so the linux-family gate
# lives HERE at the leaf (module-position mkIf is illegal: body under
# `config = mkIf`).
{
  config = lib.mkIf shared.caps.linux-family {
    home.packages = with shared.upkgs; [
      wpsoffice-cn
    ];
  };
}
