# @path: ~/projects/configs/nix-config/home/core/exp/app/dl/motrix-next.nix
# @author: redskaber
# @datetime: 2026-05-25
# @description: home::core::exp::app:dl::motrix-next


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ motrix-next ];

}



