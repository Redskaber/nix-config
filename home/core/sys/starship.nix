# @path: ~/projects/configs/nix-config/home/core/sys/starship.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::sys::starship
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.starship.enable


{ inputs
, lib
, config
, pkgs
, ...
}:
{

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
  };

  # Used user config:
  xdg.configFile."starship" = {
    source = inputs.starship-config;  # abs path
    recursive = true;                 # rec-link
    force = true;
  };

  home.sessionVariables.STARTSHIP_CONFIG = "~/.config/starship/starship.toml"

}


