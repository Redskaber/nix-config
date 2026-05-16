# @path: ~/projects/configs/nix-config/home/core/exp/app/discord.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.discord.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    # discord
    vesktop
  ];

}

