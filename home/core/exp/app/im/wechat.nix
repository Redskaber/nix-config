# @path: ~/projects/configs/nix-config/home/core/exp/app/wechat.nix
# @author: redskaber
# @datetime: 2025-12-12


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with shared.upkgs; [
    inputs.wechat.packages.${shared.arch.tag}.default
  ];

}
