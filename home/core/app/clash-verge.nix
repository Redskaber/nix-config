# @path: ~/projects/configs/nix-config/home/core/app/clash-verge.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::clash-verge


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  # system manager
  # programs.clash-verge = {
  #   enable = true;
  #   autoStart = false;
  #   serviceMode = true;
  #   tunMode = true;
  #   package = pkgs.clash-verge-rev;
  # };

  home.packages = with pkgs; [
    clash-verge-rev
  ];

}


