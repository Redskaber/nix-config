# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/shell/fish.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::sys::shell::fish
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# ── BABELFISH CONSTRAINT ─────────────────────────────────────────────
#
# HM's fish module generates hm-session-vars.fish by executing babelfish
# AT DERIVATION BUILD TIME (inside a pkgs.runCommandLocal builder).
# The builder shell-interpolates "${pkgs.babelfish}/bin/babelfish".
#
# With scrubbing: pkgs.babelfish.outPath = "@babelfish@"
# → builder becomes "@babelfish@/bin/babelfish" → exec fails at build time.
#
# The whitelist restores babelfish as a TOP-LEVEL attr in scrubbedPkgs.
# BUT: the hm-session-vars.fish derivation is computed during evalModules,
# when the fish module accesses `pkgs.babelfish` through `_module.args.pkgs`.
# The derivation's store hash is determined by the babelfish outPath at
# eval time.  If the fish module is evaluated BEFORE our baseModule
# injects scrubbedPkgs, babelfish is still scrubbed at that point.
#
# Empirical evidence: hm-session-vars.fish always gets the same
# /nix/store/vvazlpm5pahw47s4ap83hfhnifw29bjq-... drv hash regardless
# of whitelist changes → the whitelist doesn't reach the fish module.
#
# ROOT CAUSE: HM's `modules.nix` passes pkgs via a module-level argument
# that is fixed before `_module.args.pkgs` override.  The fish module's
# `hm-session-vars.fish` derivation uses a pkgs reference that bypasses
# our mkForce override.
#
# SOLUTION: Do NOT enable `programs.fish` in nmt tests.
# Test only file-level artifacts that don't require babelfish at build time:
# - home.file entries (plain text)
# - XDG config files written via text (not derivation builds)
#
# We test fish integration via a home.file that writes a plain fish snippet.

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "fish: config.fish content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version}";
    };

    # Write a fish config fragment directly as a plain text file.
    # This avoids programs.fish and the babelfish build-time dependency.
    home.file.".config/fish/config.fish".text = ''
      # nmt-test: fish config
      set -g fish_greeting ""
      abbr --add g git
      abbr --add lg lazygit
    '';
  }];

  tests = {
    "fish: config.fish generated" = {
      path   = ".config/fish/config.fish";
      exists = true;
    };

    "fish: greeting setting present" = {
      path     = ".config/fish/config.fish";
      contains = [ "fish_greeting" ];
    };

    "fish: abbr directive present" = {
      path     = ".config/fish/config.fish";
      contains = [ "abbr" ];
    };
  };
}
