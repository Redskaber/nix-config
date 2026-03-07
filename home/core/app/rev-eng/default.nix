# @path: ~/projects/configs/nix-config/home/core/app/rev-eng/default.nix
# @author: redskaber
# @datetime: 2026-03-07
# @description: home::core::app::rev-eng::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    scanmem
  ];

}

