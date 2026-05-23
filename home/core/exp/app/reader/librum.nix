# @path: ~/projects/configs/nix-config/home/core/exp/app/reader/librum.nix
# @author: redskaber
# @datetime: 2026-05-22
# @description: home::core::exp::app::reader::librum

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ librum ];

}


