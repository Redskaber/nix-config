# @path: ~/projects/configs/nix-config/tests/nmt/home/core/base/atuin.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::base::atuin
# @source: home/core/exp/sys/base/atuin.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# Asserts:
#   - .config/atuin/config.toml exists
#   - search_mode = "fuzzy" written
#   - style = "compact" written

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "atuin: config.toml content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    programs.atuin = {
      enable = true;
      settings = {
        search_mode  = "fuzzy";
        style        = "compact";
        update_check = false;
      };
    };
  }];

  tests = {
    "atuin: config.toml exists" = {
      path   = ".config/atuin/config.toml";
      exists = true;
    };

    "atuin: search_mode = fuzzy" = {
      path     = ".config/atuin/config.toml";
      contains = [ "search_mode" "fuzzy" ];
    };

    "atuin: style = compact" = {
      path     = ".config/atuin/config.toml";
      contains = [ "style" "compact" ];
    };

    "atuin: update_check = false" = {
      path     = ".config/atuin/config.toml";
      contains = [ "update_check" ];
    };
  };
}
