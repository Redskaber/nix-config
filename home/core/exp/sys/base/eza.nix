# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/eza.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::base::eza
# - https://nix-community.github.io/home/options.xhtml#opt-programs.eza.enable


{ inputs
, shared
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


