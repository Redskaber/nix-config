# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/tmux.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::sys::base::tmux
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.tmux writes .config/tmux/tmux.conf via xdg.configFile.*.text
# (plain string, NOT a formats.* derivation).
#
# HM 25.11 tmux module unconditionally writes:
#   set  -g history-limit     <N>
#   set  -g default-terminal  "<term>"
# with alignment spaces.  `grep -qF "history-limit"` is reliable.
#
# programs.tmux.keyMode = "vi" writes:
#   setw -g mode-keys vi
# so contains = [ "mode-keys" ] is safe.

{ inputs, shared, lib, ...}:

lib.nmt.buildHomeManagerTest {
  description = "tmux: config file content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version}";
    };

    programs.tmux = {
      enable       = true;
      historyLimit = 50000;
      keyMode      = "vi";
      terminal     = "tmux-256color";
    };
  }];

  tests = {
    "tmux: config file exists" = {
      path   = ".config/tmux/tmux.conf";
      exists = true;
    };

    "tmux: history-limit directive written" = {
      path     = ".config/tmux/tmux.conf";
      contains = [ "history-limit" ];
    };

    "tmux: vi key-mode written" = {
      path     = ".config/tmux/tmux.conf";
      contains = [ "mode-keys" ];
    };
  };
}
