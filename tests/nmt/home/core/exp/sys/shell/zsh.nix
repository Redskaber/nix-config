# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/shell/zsh.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::sys::shell::zsh
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.zsh writes .zshrc as plain text.
# HM 25.11 zsh module generates HISTSIZE via history.size option.
# The option name in HM is programs.zsh.history.size (not .history = { size = ... }).
#
# What HM actually writes for zsh history:
#   HISTSIZE=50000
#   SAVEHIST=50000
# Both are set when history.size / history.save are configured.
#
# For autosuggestions and syntax-highlighting: HM sources the plugin nix store path.
# With scrubbing those paths become "@zsh-autosuggestions@" etc., but the
# source command line IS written in .zshrc as plain text (just with broken path).
# grep -qF "zsh-autosuggestions" finds the scrubbed placeholder string.

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "zsh: .zshrc content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    programs.zsh = {
      enable = true;
      autosuggestion.enable         = true;
      syntaxHighlighting.enable     = true;
      historySubstringSearch.enable = true;
      history = {
        size = 50000;
        save = 50000;
      };
      shellAliases = {
        vi  = "nvim";
        vim = "nvim";
        ll  = "ls -la";
      };
    };
  }];

  tests = {
    "zsh: .zshrc generated" = {
      path   = ".zshrc";
      exists = true;
    };

    # HM writes HISTSIZE=N in the generated .zshrc
    "zsh: HISTSIZE present" = {
      path     = ".zshrc";
      contains = [ "HISTSIZE" ];
    };

    # plugin source line contains scrubbed placeholder "@zsh-autosuggestions@"
    # grep -qF "zsh-autosuggestions" finds it
    "zsh: autosuggestions sourced" = {
      path     = ".zshrc";
      contains = [ "zsh-autosuggestions" ];
    };

    "zsh: syntax-highlighting sourced" = {
      path     = ".zshrc";
      contains = [ "zsh-syntax-highlighting" ];
    };

    # alias written as: vi='nvim' or vi = 'nvim'
    "zsh: nvim alias present" = {
      path     = ".zshrc";
      contains = [ "nvim" ];
    };
  };
}
