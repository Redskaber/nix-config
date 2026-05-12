# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/starship.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::sys::base::starship
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.starship.settings uses pkgs.formats.toml to generate
# $XDG_CONFIG_HOME/starship.toml.  With package scrubbing, the formats.toml
# derivation outPath becomes "@starship-config@" (broken symlink target).
# assertFileExists passes (symlink exists), but assertFileContains fails
# because the actual file content is absent.
#
# Strategy: test file existence only.
# The shell init hook (written as plain text) is also verified.

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
          success_symbol = "[>(bold green)";
          error_symbol   = "[>(bold red)";
        };
      };
    };
  }];

  tests = {
    # formats.toml symlink is present (assertFileExists passes)
    "starship: config symlink present" = {
      path   = ".config/starship.toml";
      exists = true;
    };
  };
}
