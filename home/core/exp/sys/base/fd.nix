# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/fd.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::base::fd
# - https://nix-community.github.io/home/options.xhtml#opt-programs.fd.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  programs.fd = {
    enable = true;
    ignores = [
      ".git/"
      "*.bak"
    ];
  };
}


