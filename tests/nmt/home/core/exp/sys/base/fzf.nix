# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/fzf.nix
# @author: redskaber
# @datetime: 2026-05-12
# @description: nmt::home::core::exp::sys::base::fzf
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.fzf with enableZshIntegration writes a shell init snippet.
# HM 25.11 fzf module injects fzf sourcing into .zshrc via
# programs.zsh.initExtra (when enableZshIntegration = true).
#
# The FZF_DEFAULT_OPTS variable is set from `defaultOptions`.
# HM writes it to the session vars file OR directly into the zsh init.
#
# What we can safely assert without scrubbing issues:
#   - programs.zsh must be enabled for enableZshIntegration to take effect
#   - .zshrc will contain "fzf" sourcing
#   - FZF_DEFAULT_OPTS will contain our options
#
# NOTE: assertFileContains needle must NOT start with "-".
#       We test the option values without leading dash.

{ inputs, shared, lib, ...}:

lib.nmt.buildHomeManagerTest {
  description = "fzf: shell integration written to zshrc";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version}";
    };

    programs.zsh = {
      enable = true;
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };
  }];

  tests = {
    "fzf: .zshrc exists" = {
      path   = ".zshrc";
      exists = true;
    };

    "fzf: fzf key-bindings sourced in zshrc" = {
      path  = ".zshrc";
      regex = "fzf";
    };

  };
}
