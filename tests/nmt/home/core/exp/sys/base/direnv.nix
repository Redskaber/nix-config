# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/direnv.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::sys::base::direnv
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.direnv:
#   - nix-direnv.enable = true  →  writes real file via nix-direnv store path
#     (nix-direnv is in the whitelist so it keeps a valid store path)
#   - enableBashIntegration = true  →  writes hook into .bashrc
#     (programs.bash.enable required for .bashrc to be generated)
#   - enableZshIntegration = true   →  writes hook into .zshrc
#     (programs.zsh.enable required)
#
# HM writes the direnv hook as:
#   eval "$(direnv hook bash)"   in .bashrc
#   eval "$(direnv hook zsh)"    in .zshrc
# grep -qF "direnv hook" matches both.

{ inputs, shared, lib, ...}:

lib.nmt.buildHomeManagerTest {
  description = "direnv: dotfile content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "${shared.version}";
    };

    programs.bash.enable = true;
    programs.zsh.enable  = true;

    programs.direnv = {
      enable                = true;
      nix-direnv.enable     = true;
      enableBashIntegration = true;
      enableZshIntegration  = true;
    };
  }];

  tests = {
    "direnv: nix-direnv lib file exists" = {
      path   = ".config/direnv/lib/hm-nix-direnv.sh";
      exists = true;
    };

    "direnv: bash hook written" = {
      path     = ".bashrc";
      contains = [ "direnv hook" ];
    };

    "direnv: zsh hook written" = {
      path     = ".zshrc";
      contains = [ "direnv hook" ];
    };
  };
}
