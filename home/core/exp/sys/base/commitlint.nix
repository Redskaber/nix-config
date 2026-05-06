# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/commitlint.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::commitlint
# depends node.js => from env::default sup (project level)

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    commitlint
  ];

  home.file.".commitlintrc.js" = {
    source = "${inputs.commit-config}/commitlint.config.js";
    force = true;
  };

}


