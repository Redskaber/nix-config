# @path: ~/projects/configs/nix-config/src/core/app/kitty.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/src/options.xhtml#opt-programs.kitty.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  kitty_path = "${config.home.profileDirectory}/bin/kitty";
in {

  programs.kitty = {
    enable = true;
    package = config.lib.nixGL.wrap pkgs.kitty;

    # themeFile = "Catppuccin-Mocha";  # from kitty-themes
    # font = {
    #   package = pkgs.jetbrains-mono;
    #   name = "JetBrainsMono Nerd Font";
    #   size = 12;
    # };
    # settings = {
    #   scrollback_lines = 10000;
    #   enable_audio_bell = false;
    #   update_check_interval = 0;
    #   confirm_os_window_close = 0;  # close is kill
    #   window_padding_width = 8 ;
    #   background_opacity = 0.95;
    #   allow_remote_control = "socket-only";
    #   listen_on = "unix:/tmp/kitty";
    # };
    # keybindings = {
    #   "ctrl+shift+v" = "paste_from_clipboard";
    #   "ctrl+shift+c" = "copy_to_clipboard";
    #   "alt+enter" = "new_tab";
    #   "ctrl+shift+t" = "new_tab";
    #   "ctrl+shift+w" = "close_tab";
    #   "ctrl+shift+q" = "quit";
    #   "ctrl+shift+up" = "increase_font_size";
    #   "ctrl+shift+down" = "decrease_font_size";
    #   "ctrl+shift+0" = "reset_font_size";
    #   # Quake-style toggle (need quick-access-terminal kitten)
    #   "f12" = "kitten quick-access-terminal";
    # };
    # shellIntegration = {
    #   mode = "no-cursor";
    #   enableBashIntegration = true;
    #   enableZshIntegration = true;
    #   enableFishIntegration = true;
    # };
    # enableGitIntegration = true;
    # # Quick Access Terminal config(Quake Terminal)
    # quickAccessTerminalConfig = {
    #   start_as_hidden = true;
    #   hide_on_focus_loss = true;
    #   background_opacity = 0.88;
    #   height = 60;
    #   location = "top";
    # };
    # # append kitty.conf G
    # extraConfig = ''
    #   map f1 kitten hints
    # '';
  };

  # Used user config:
  xdg.configFile."kitty" = {
    source = inputs.kitty-config;  # abs path
    recursive = true;              # rec-link
    force = true;
  };

  home.activation.ensure_kitty_in_hyprland = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! [ -e /bin/kitty ]; then
      echo "  WARNING: /bin/kitty not found."
      echo "  Consider running the following to symlink Kitty into /bin:"
      echo "      sudo ln -s ${kitty_path} /bin/kitty"
      echo "  Or ensure your PATH includes ${config.home.profileDirectory}/bin"
    fi
  '';

}


