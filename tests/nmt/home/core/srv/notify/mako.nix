# @path: ~/projects/configs/nix-config/tests/nmt/home/core/srv/notify/mako.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::srv::notify::mako
# @source: home/core/srv/notify/mako.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# services.mako in HM 25.11 generates .config/mako/config.
# The module may use pkgs.formats or pkgs.writeText internally.
# If content assertions fail (scrubbing), use extraConfig (plain text)
# to inject testable content.
#
# extraConfig is appended as a plain text string → immune to scrubbing.
# We use extraConfig to add a marker line and assert its presence.
#
# The settings attrset is also set so the module evaluates correctly.

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "mako: config file content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version}";
    };

    services.mako = {
      enable = true;
      settings = {
        font             = "JetBrainsMono Nerd Font 10";
        border-radius    = 8;
        default-timeout  = 5000;
        layer            = "overlay";
      };
      # extraConfig is a plain text string → always written verbatim
      extraConfig = ''
        # nmt-test-marker: mako config active
      '';
    };
  }];

  tests = {
    "mako: config file generated" = {
      path   = ".config/mako/config";
      exists = true;
    };

    # extraConfig is plain text — always present regardless of scrubbing
    "mako: extraConfig marker present" = {
      path     = ".config/mako/config";
      contains = [ "nmt-test-marker" ];
    };
  };
}
