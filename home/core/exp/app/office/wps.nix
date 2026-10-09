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
# T5.10: wps-office-cn is a Linux deb repack — on any non-linux-family
# host it evaluates to an installable-but-dead blob. The `lean` app-set
# row keeps this tree for its cross-platform siblings (pandoc, poppler),
# so the linux-family caps gate lives HERE, at the leaf that needs it
# (body under `config = mkIf` — module-position mkIf is illegal).
{
  config = lib.mkIf shared.caps.linux-family {
    home.packages = with shared.upkgs; [
      wpsoffice-cn
    ];
  };
}
