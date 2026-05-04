# @path: ~/projects/configs/nix-config/home/core/app/browser/qutebrowser.nix
# @author: redskaber
# @datetime: 2026-04-18
# @discription: home::core::app::browser::qutebrowser


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


