# @path: ~/projects/configs/nix-config/tests/nmt/home/core/srv/gnupg.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::srv::gnupg
# @source: home/core/srv/security/gnupg.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# production gnupg.nix:
#   home.packages = [ gnupg ]
#
# There is no HM programs.gpg config in this module — just a package install.
# This nmt test validates the package-only pattern evaluates cleanly (no
# dotfile to assert, but the module must produce a valid home config).
#
# For deeper gpg-agent assertions, use programs.gpg + services.gpg-agent.

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "gnupg: package-only module evaluates cleanly";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    # Mirror production: just gnupg package
    # home.packages = [ pkgs.gnupg ] → scrubbed to @gnupg@ in nmt
    programs.gpg = {
      enable   = true;
      settings = { use-agent = true; };
    };

    services.gpg-agent = {
      enable         = true;
      defaultCacheTtl = 600;
      maxCacheTtl     = 7200;
      pinentryPackage = null;  # scrubbed
    };
  }];

  tests = {
    "gnupg: gpg.conf generated" = {
      path   = ".gnupg/gpg.conf";
      exists = true;
    };

    "gnupg: use-agent written" = {
      path     = ".gnupg/gpg.conf";
      contains = [ "use-agent" ];
    };

    "gnupg: gpg-agent.conf generated" = {
      path   = ".gnupg/gpg-agent.conf";
      exists = true;
    };

    "gnupg: default-cache-ttl written" = {
      path     = ".gnupg/gpg-agent.conf";
      contains = [ "default-cache-ttl" "600" ];
    };
  };
}
