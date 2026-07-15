# @path: ~/projects/configs/nix-config/tests/nmt/home/core/srv/security/gnupg.nix
# REWRITTEN
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::srv::gnupg
# @source: home/core/srv/security/gnupg.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# NOTE on pinentry:
#   services.gpg-agent.pinentryPackage = null is NOT a valid value — the
#   option expects a package derivation or lib.mkDefault pkgs.pinentry.
#   In nmt tests, pinentry is scrubbed to "@pinentry@".  We simply omit
#   the pinentryPackage option so HM uses its built-in default (scrubbed).
#
# Asserts:
#   - .gnupg/gpg.conf exists
#   - use-agent written
#   - .gnupg/gpg-agent.conf exists
#   - default-cache-ttl written

{ inputs, shared, lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "gnupg: package-only module evaluates cleanly";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version.value}";
    };

    programs.gpg = {
      enable   = true;
      settings = { use-agent = true; };
    };

    services.gpg-agent = {
      enable          = true;
      defaultCacheTtl = 600;
      maxCacheTtl     = 7200;
      # pinentryPackage intentionally omitted — scrubbed default is fine
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

    "gnupg: default-cache-ttl key written" = {
      path     = ".gnupg/gpg-agent.conf";
      contains = [ "default-cache-ttl" ];
    };
  };
}
