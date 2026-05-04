# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/direnv.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::base::direnv
# - https://nix-community.github.io/home/options.xhtml#opt-programs.direnv.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    # enableFishIntegration = true;   # (readonly)
    # config = {};
    nix-direnv.enable = true;
    # stdlib = "# Managed by Home Manager - enables nix-direnv";
  };
}


