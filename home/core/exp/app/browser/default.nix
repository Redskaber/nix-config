# @path: ~/projects/configs/nix-config/home/core/exp/app/browser/default.nix
# @author: redskaber
# @datetime: 2026-05-15
# @description: home::core::exp::app::browser::default

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./google-chrome.nix
    ./qutebrowser.nix
    ./w3m.nix
    # ./zen-browser.nix
  ];


}


