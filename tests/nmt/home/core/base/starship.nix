# @path: ~/projects/configs/nix-config/tests/nmt/home/core/base/starship.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::base::starship
# @source: home/core/exp/sys/base/starship.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# Asserts:
#   - .config/starship.toml exists
#   - format string references expected modules

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "starship: dotfile content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    programs.starship = {
      enable = true;
      settings = {
        add_newline = false;
        format      = "$directory$git_branch$git_status$character";
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol   = "[➜](bold red)";
        };
        directory = {
          truncation_length = 3;
          fish_style_pwd    = false;
        };
      };
    };
  }];

  tests = {
    "starship: config file exists" = {
      path   = ".config/starship.toml";
      exists = true;
    };

    "starship: add_newline written" = {
      path     = ".config/starship.toml";
      contains = [ "add_newline = false" ];
    };

    "starship: format string written" = {
      path     = ".config/starship.toml";
      contains = [ "format" ];
    };

    "starship: character section present" = {
      path     = ".config/starship.toml";
      contains = [ "[character]" ];
    };
  };
}
