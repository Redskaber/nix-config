# @path: ~/projects/configs/nix-config/home/core/exp/app/img/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::app::img::default



{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./ghostscript.nix
    ./gimp.nix
    ./imagemagick.nix
    ./imv.nix
    ./mermaid-cli.nix
    ./tectonic.nix
  ];


}


