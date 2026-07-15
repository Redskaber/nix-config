# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/fd.nix
# @author: redskaber
# @datetime: 2026-05-12
# @description: nmt::home::core::exp::sys::base::fd
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.fd generates:
#   ~/.config/fd/ignore   ← .gitignore-syntax ignore file (one entry per line)
#
# The ignore list from the source module:
#   ignores = [ ".git/" "*.bak" ];
# HM writes each entry on its own line.

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "fd: ignore file written";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version}";
    };

    programs.fd = {
      enable  = true;
      ignores = [
        ".git/"
        "*.bak"
      ];
    };
  }];

  tests = {
    "fd: ignore file exists" = {
      path   = ".config/fd/ignore";
      exists = true;
    };

    "fd: .git/ entry written" = {
      path     = ".config/fd/ignore";
      contains = [ ".git/" ];
    };

    "fd: *.bak entry written" = {
      path     = ".config/fd/ignore";
      contains = [ "*.bak" ];
    };
  };
}
