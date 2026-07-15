# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/atuin.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::sys::base::atuin
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.atuin.settings uses pkgs.formats.toml to generate
# $XDG_CONFIG_HOME/atuin/config.toml.
# With scrubbing, the derivation outPath = "@atuin-config@" (broken symlink).
# assertFileExists passes; assertFileContains on generated keys fails.
#
# Strategy: assert file exists (symlink), and assert shell integration
# hook is injected into the shell rc (which uses plain text).

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "atuin: config.toml content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version}";
    };

    # zsh needed for shell integration hook assertion
    programs.zsh.enable = true;

    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        search_mode  = "fuzzy";
        style        = "compact";
        update_check = false;
      };
    };
  }];

  tests = {
    # formats.toml symlink exists
    "atuin: config.toml symlink present" = {
      path   = ".config/atuin/config.toml";
      exists = true;
    };

    # shell integration: written as plain text in .zshrc
    "atuin: zsh integration present" = {
      path     = ".zshrc";
      contains = [ "atuin" ];
    };
  };
}
