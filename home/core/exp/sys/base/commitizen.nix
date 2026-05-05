# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/commitizen.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::commitizen
# depends: python + git

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    commitizen
  ];

  home.file.".cz.toml".source = "${inputs.commit-config}/.cz.toml";

}


