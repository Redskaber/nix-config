# @path: ~/projects/configs/nix-config/home/core/sys/fd.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: home::core::sys::fd
# - https://nix-community.github.io/home/options.xhtml#opt-programs.fd.enable


{ inputs
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


