# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/husky.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::husky
# depends node.js => from env::default sup

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    husky
  ];

}


