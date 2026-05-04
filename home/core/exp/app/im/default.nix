# @path: ~/projects/configs/nix-config/home/core/app/im/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::app::im::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./discord.nix
    ./qq.nix
    ./wechat.nix
  ];


}


