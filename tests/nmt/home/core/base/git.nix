# @path: ~/projects/configs/nix-config/tests/nmt/home/core/base/git.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::base::git
# @source: home/core/exp/sys/base/git.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval, <10s)
#
# Asserts:
#   - .config/git/config contains [user] name/email
#   - .config/git/config contains [init] defaultBranch = main
#   - .config/git/config contains [pull] rebase = true
#   - programs.delta generates its config block
#   - programs.lazygit generates config file

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "git: dotfile content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    programs.git = {
      enable    = true;
      userName  = "redskaber";
      userEmail = "redskaber@foxmail.com";
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase        = true;
      };
    };

    programs.delta = {
      enable = true;
      options = {
        navigate     = true;
        side-by-side = true;
        line-numbers = true;
      };
    };

    programs.lazygit = {
      enable   = true;
      settings = { git.paging.colorArg = "always"; };
    };
  }];

  tests = {
    "git: config file exists" = {
      path   = ".config/git/config";
      exists = true;
    };

    "git: user.name written" = {
      path     = ".config/git/config";
      contains = [ "[user]" "name = redskaber" ];
    };

    "git: user.email written" = {
      path     = ".config/git/config";
      contains = [ "email = redskaber@foxmail.com" ];
    };

    "git: init.defaultBranch = main" = {
      path     = ".config/git/config";
      contains = [ "defaultBranch = main" ];
    };

    "git: pull.rebase = true" = {
      path     = ".config/git/config";
      contains = [ "rebase = true" ];
    };

    "git: delta block present" = {
      path     = ".config/git/config";
      contains = [ "[delta]" ];
    };

    "git: lazygit config exists" = {
      path   = ".config/lazygit/config.yml";
      exists = true;
    };
  };
}
