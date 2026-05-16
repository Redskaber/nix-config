# @path: ~/projects/configs/nix-config/home/core/exp/app/browser/qutebrowser.nix
# @author: redskaber
# @datetime: 2026-04-18
# @description: home::core::exp::app::browser::qutebrowser


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    qutebrowser
  ];

}


