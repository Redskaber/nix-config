# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/git-filter-repo.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::base::git-filter-repo
# Quickly rewrite git repository history


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [ git-filter-repo ];

}


