# @path: ~/projects/configs/nix-config/home/core/sys/eza.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: home::core::sys::eza
# - https://nix-community.github.io/home/options.xhtml#opt-programs.eza.enable


{ inputs
, lib
, config
, pkgs
, ...
}:
{

  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
}


