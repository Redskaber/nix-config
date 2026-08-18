# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/yazi/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::yazi::default
# @directory: https://nix-community.github.io/home-manager/options.xhtml


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
let
  settings = import ./settings.nix;
  keymap = import ./keymap.nix;
in
{
  home.file.".config/yazi/theme.toml" = lib.mkForce { source = ./theme.toml; };

  programs.yazi = shared.shellIntegrations // {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "yy";
    settings = settings;
    keymap = keymap;
    plugins = {
      lazygit = shared.pkgs.yaziPlugins.lazygit;
      full-border = shared.pkgs.yaziPlugins.full-border;
      git = shared.pkgs.yaziPlugins.git;
      smart-enter = shared.pkgs.yaziPlugins.smart-enter;
    };

    initLua = ''
      require("full-border"):setup()
         require("git"):setup()
         require("smart-enter"):setup {
           open_multi = true,
         }
    '';
  };


}


