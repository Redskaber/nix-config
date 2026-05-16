# @path: ~/projects/configs/nix-config/home/core/exp/app/showmethekey.nix
# @author: redskaber
# @datetime: 2026-04-22
# @discription: home::core::exp::app::showmethekey


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [ showmethekey ];

}


