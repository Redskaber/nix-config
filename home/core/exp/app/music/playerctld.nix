# @path: ~/projects/configs/nix-config/home/core/exp/app/music/playerctld.nix
# @author: redskaber
# @datetime: 2026-02-14
# @description: home::core::exp::app::music::playerctld

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  # ===== MPRIS 代理 (统一媒体控制) =====
  services.playerctld = {
    enable = true;
    package = pkgs.playerctl;
  };

}


