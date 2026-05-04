# @path: ~/projects/configs/nix-config/home/core/base/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::base::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./fonts.nix
    ./i18n.nix
    ./portal.nix
  ];


}


