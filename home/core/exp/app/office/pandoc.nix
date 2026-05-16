# @path: ~/projects/configs/nix-config/home/core/exp/app/office/pandoc.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::office::pandoc
# - Conversion between documentation formats

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    pandoc
    texliveMinimal
  ];

}



