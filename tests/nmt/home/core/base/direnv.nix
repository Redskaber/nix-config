# @path: ~/projects/configs/nix-config/tests/nmt/home/core/base/direnv.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::base::direnv
# @source: home/core/exp/sys/base/direnv.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# Asserts:
#   - .config/direnv/direnv.toml exists (written by HM programs.direnv)
#   - nix-direnv hook path injected into shell rc files

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "direnv: dotfile content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    programs.direnv = {
      enable              = true;
      nix-direnv.enable   = true;
      enableBashIntegration = true;
      enableZshIntegration  = true;
    };
  }];

  tests = {
    "direnv: .config/direnv/direnvrc exists" = {
      path   = ".config/direnv/direnvrc";
      exists = true;
    };

    "direnv: nix-direnv source line present" = {
      path     = ".config/direnv/direnvrc";
      contains = [ "nix-direnv" ];
    };
  };
}
