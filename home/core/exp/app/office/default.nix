# @path: ~/projects/configs/nix-config/home/core/exp/app/office/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::office::default



{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./pandoc.nix
    ./pdf.nix
    ./unoconv.nix
    ./wps.nix
  ];


}


