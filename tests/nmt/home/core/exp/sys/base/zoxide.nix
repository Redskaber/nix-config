# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/zoxide.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::sys::base::zoxide
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.zoxide writes shell init hooks as plain text.
# HM writes to .bashrc: `eval "$(zoxide init bash)"`
# and to .zshrc:        `eval "$(zoxide init zsh)"`
#
# programs.bash.enable = true is REQUIRED for HM to generate .bashrc.
# programs.zsh.enable  = true is REQUIRED for HM to generate .zshrc.

{ inputs, shared, lib, ...}:

lib.nmt.buildHomeManagerTest {
  description = "zoxide: shell integration hook injected";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version.value}";
    };

    programs.bash.enable = true;
    programs.zsh.enable  = true;

    programs.zoxide = {
      enable                = true;
      enableBashIntegration = true;
      enableZshIntegration  = true;
    };
  }];

  tests = {
    "zoxide: .bashrc exists" = {
      path   = ".bashrc";
      exists = true;
    };

    "zoxide: zoxide init in .bashrc" = {
      path     = ".bashrc";
      contains = [ "zoxide init" ];
    };

    "zoxide: zoxide init in .zshrc" = {
      path     = ".zshrc";
      contains = [ "zoxide init" ];
    };
  };
}
