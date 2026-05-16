# @path: ~/projects/configs/nix-config/home/core/exp/app/game/minecraft.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::exp::app::game::minecraft
# - prismlauncher: free, open source


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [ prismlauncher ];

}


