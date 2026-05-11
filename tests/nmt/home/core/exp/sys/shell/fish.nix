# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/shell/fish.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::sys::shell::fish
# @source: home/core/exp/sys/shell/fish.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# Asserts:
#   - .config/fish/config.fish exists
#   - abbreviations injected (preferAbbrs)
#   - interactiveShellInit block present

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "fish: config.fish content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    programs.fish = {
      enable      = true;
      preferAbbrs = true;
      shellAbbrs  = {
        g   = "git";
        lg  = "lazygit";
        cat = "bat";
      };
      interactiveShellInit = ''
        set -g fish_greeting ""
      '';
    };
  }];

  tests = {
    "fish: config.fish generated" = {
      path   = ".config/fish/config.fish";
      exists = true;
    };

    "fish: greeting init block present" = {
      path     = ".config/fish/config.fish";
      contains = [ "fish_greeting" ];
    };

    "fish: abbreviations file generated" = {
      path   = ".config/fish/config.fish";
      exists = true;
    };

    "fish: abbr 'g' for git present" = {
      path     = ".config/fish/config.fish";
      contains = [ "abbr" "git" ];
    };
  };
}
