# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/starship.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::starship
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.starship.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  programs.starship = shared.shellIntegrations // {
    enable = true;
  };

  # Used user config:
  xdg.configFile."starship.toml".source = "${inputs.starship-config}/starship.toml";

}


