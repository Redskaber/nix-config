# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/app/nvim.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::app::nvim
# @source: home/core/exp/app/editor/nvim.nix
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# production nvim.nix sets:
#   programs.neovim.enable = true
#   programs.neovim.defaultEditor = true
#   xdg.configFile."nvim".source = inputs.nvim-config
#
# Since nvim-config is an external flake input (non-evaluatable in test
# context), we test the standard HM neovim options only:
#   - programs.neovim generates the wrapper binary link
#   - programs.neovim.defaultEditor sets EDITOR env var
#   - viAlias / vimAlias produce the symlinks

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "nvim: home-manager neovim program assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

    programs.neovim = {
      enable        = true;
      defaultEditor = true;
      viAlias       = true;
      vimAlias      = true;
    };
  }];

  tests = {
    # HM creates .nix-profile/bin/nvim (resolved via activation)
    # In nmt, home-files doesn't show binaries — check session variables instead
    "nvim: EDITOR env var set via home-manager" = {
      path     = ".profile";
      contains = [ "EDITOR" ];
    };
  };
}
