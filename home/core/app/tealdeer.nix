# @path: ~/projects/configs/nix-config/home/core/app/tealdeer.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.tealdeer.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  programs.tealdeer = {
    enable = true;
    settings = {
      display.compact = false;
      display.use_pager = true;
      updates.auto_update = true;
    };
  };

}


