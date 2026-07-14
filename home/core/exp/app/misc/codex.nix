# @path: ~/projects/configs/nix-config/home/core/exp/app/misc/codex.nix
# @author: redskaber
# @datetime: 2026-06-29
# @discription: home::core::exp::app::misc::codex


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [ codex ];

}


