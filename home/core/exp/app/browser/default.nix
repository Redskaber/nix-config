# @path: ~/projects/configs/nix-config/home/core/app/browser/default.nix
# @author: redskaber
# @datetime: 2026-04-18
# @description: home::core::app::browser::default

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


