# @path: ~/projects/configs/nix-config/tests/nmt/home/core/base/zoxide.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::base::zoxide
# @source: home/core/exp/sys/base/zoxide.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.zoxide does not write a standalone config file; HM wires
# the init hook into each shell's rc.  We assert the hook appears in
# the bash sessionVariables or via the generated bash profile.

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "zoxide: shell integration hook injected";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    programs.zoxide = {
      enable                = true;
      enableBashIntegration = true;
      enableZshIntegration  = true;
    };
  }];

  tests = {
    # HM generates .profile / .bashrc which source the init hook
    "zoxide: bash rc generated" = {
      path   = ".bashrc";
      exists = true;
    };

    "zoxide: zoxide init hook in bashrc" = {
      path     = ".bashrc";
      contains = [ "zoxide init" ];
    };
  };
}
