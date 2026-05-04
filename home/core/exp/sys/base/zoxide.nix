# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/zoxide.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::zoxide
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.zoxide.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    # options: extra params
    # options = [ "--no-cmd" ];
  };
}


