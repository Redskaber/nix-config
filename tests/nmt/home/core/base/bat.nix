# @path: ~/projects/configs/nix-config/tests/nmt/home/core/base/bat.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::base::bat
# @source: home/core/exp/sys/base/bat.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# Asserts:
#   - .config/bat/config exists
#   - theme = "gruvbox-dark" written
#   - pager value present

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "bat: config file content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    programs.bat = {
      enable = true;
      config = {
        theme    = "gruvbox-dark";
        pager    = "less -CN";
        map-syntax = [ "*.conf:TOML" ];
      };
    };
  }];

  tests = {
    "bat: config file exists" = {
      path   = ".config/bat/config";
      exists = true;
    };

    "bat: theme written" = {
      path     = ".config/bat/config";
      contains = [ "--theme=gruvbox-dark" ];
    };

    "bat: pager written" = {
      path     = ".config/bat/config";
      contains = [ "--pager" ];
    };
  };
}
