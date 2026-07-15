# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/bat.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::sys::base::bat
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.bat writes .config/bat/config with lines like:
#   --theme=gruvbox-dark
#   --pager=less -CN
#   --map-syntax=*.conf:TOML
#
# IMPORTANT: assertFileContains calls `grep -qF "$needle" "$file"`.
# When needle = "--pager", grep receives "--pager" as a flag → error.
# Fix: use needle "pager" (substring present in "--pager=less -CN").

{ inputs, shared, lib, ...}:

lib.nmt.buildHomeManagerTest {
  description = "bat: config file content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version.value}";
    };

    programs.bat = {
      enable = true;
      config = {
        theme    = "gruvbox-dark";
        pager    = "less -CN";
        map-syntax = [ "*.conf:TOML" ];
      };
    };
  }];

  tests = {
    "bat: config file exists" = {
      path   = ".config/bat/config";
      exists = true;
    };

    "bat: theme written" = {
      path     = ".config/bat/config";
      contains = [ "theme=gruvbox-dark" ];
    };

    # needle "pager" avoids the "--" leading-dash grep-flag issue
    "bat: pager written" = {
      path     = ".config/bat/config";
      contains = [ "pager" ];
    };
  };
}
