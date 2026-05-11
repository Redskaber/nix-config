# @path: ~/projects/configs/nix-config/tests/nmt/home/core/srv/mako.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::srv::mako
# @source: home/core/srv/notify/mako.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# Asserts:
#   - .config/mako/config generated
#   - font written
#   - background-color written
#   - border-radius written
#   - default-timeout written

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "mako: config file content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    services.mako = {
      enable = true;
      settings = {
        font             = "JetBrainsMono Nerd Font 10";
        background-color = "#1e1e2e";
        text-color       = "#cdd6f4";
        border-color     = "#89b4fa";
        border-radius    = 8;
        default-timeout  = 5000;
        layer            = "overlay";
      };
    };
  }];

  tests = {
    "mako: config file generated" = {
      path   = ".config/mako/config";
      exists = true;
    };

    "mako: font written" = {
      path     = ".config/mako/config";
      contains = [ "font=JetBrainsMono" ];
    };

    "mako: background-color written" = {
      path     = ".config/mako/config";
      contains = [ "background-color=#1e1e2e" ];
    };

    "mako: border-radius written" = {
      path     = ".config/mako/config";
      contains = [ "border-radius=8" ];
    };

    "mako: default-timeout written" = {
      path     = ".config/mako/config";
      contains = [ "default-timeout=5000" ];
    };

    "mako: layer=overlay written" = {
      path     = ".config/mako/config";
      contains = [ "layer=overlay" ];
    };
  };
}
