# @path: ~/projects/configs/nix-config/home/core/exp/app/browser/google-chrome.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diescription: home::core::exp::app::browser::google-chrome


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    google-chrome
  ];

}

