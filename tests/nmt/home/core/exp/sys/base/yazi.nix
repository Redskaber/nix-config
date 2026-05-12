# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/yazi.nix
# @author: redskaber
# @datetime: 2026-05-12
# @description: nmt::home::core::exp::sys::base::yazi
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.yazi in HM generates:
#   ~/.config/yazi/yazi.toml   ← from settings (pkgs.formats.toml → SCRUBBED)
#   ~/.config/yazi/keymap.toml ← from keymap   (pkgs.formats.toml → SCRUBBED)
#   ~/.config/yazi/init.lua    ← from initLua  (plain text → assertable)
#
# pkgs.formats.toml produces a derivation → scrubbing replaces outPath with
# "@yazi-toml@". The TOML files exist as symlinks but contain no text content.
# Only assertFileExists can be used for them, not assertFileContains.
#
# initLua IS plain text (written via home.file mechanism) and IS assertable.
#
# Plugins use scrubbed derivations → asserting plugin paths would fail.
# We keep the test minimal: assert the lua file exists and contains our text.
#
# The production plugin configuration (yaziPlugins.*) requires real package
# closures → tested at Plane 2 (QEMU VM). Here we use a plain initLua only.

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "yazi: config files present";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    programs.yazi = {
      enable            = true;
      shellWrapperName  = "yy";

      settings = {
        mgr = {
          ratio         = [ 1 4 3 ];
          sort_by       = "alphabetical";
          sort_dir_first = true;
          show_hidden   = false;
          show_symlink  = true;
          scrolloff     = 5;
        };
      };

      # Plain text — assertable after scrubbing
      initLua = ''
        -- nmt-test marker
        require("full-border"):setup()
      '';
    };
  }];

  tests = {
    # TOML files are scrubbed derivations → only existence check
    "yazi: yazi.toml symlink present" = {
      path   = ".config/yazi/yazi.toml";
      exists = true;
    };

    # initLua is plain text → content assertable
    "yazi: init.lua exists" = {
      path   = ".config/yazi/init.lua";
      exists = true;
    };

    "yazi: init.lua marker written" = {
      path     = ".config/yazi/init.lua";
      contains = [ "nmt-test marker" ];
    };

    "yazi: full-border require written" = {
      path     = ".config/yazi/init.lua";
      contains = [ "full-border" ];
    };
  };
}
