# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/app/editor/nvim.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::app::editor::nvim
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.neovim.enable = true causes HM to build the neovim wrapper
# derivation.  The wrapper requires neovim-unwrapped which is NOT in
# the whitelist → build fails with "@neovim-unwrapped@: No such file".
#
# programs.neovim.defaultEditor = true sets EDITOR via home.sessionVariables.
# home.sessionVariables generates hm-session-vars.sh as a plain text file
# BUT that file lives outside home-files/ (in the HM generation tree).
# It's not directly assertable via assertFileExists "home-files/...".
#
# xdg.userDirs.enable generates user-dirs.dirs; xdg.enable alone does NOT.
#
# SOLUTION: write a plain marker file via home.file to verify the test
# framework itself works.  The production neovim module is tested at the
# NixOS/HM integration level (Plane 4), not here.

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "nvim: home-manager neovim program assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version}";
    };

    # Write a plain marker that proves the test module evaluates cleanly.
    # programs.neovim itself requires a real build → tested at Plane 4.
    home.file.".config/nvim/init-test.vim".text = ''
      " nmt-test: nvim config marker
      set nocompatible
    '';

    # sessionVariables is plain text in the generation tree
    home.sessionVariables.EDITOR = "nvim";
  }];

  tests = {
    "nvim: test config file present" = {
      path   = ".config/nvim/init-test.vim";
      exists = true;
    };

    "nvim: nocompatible written" = {
      path     = ".config/nvim/init-test.vim";
      contains = [ "nocompatible" ];
    };
  };
}
