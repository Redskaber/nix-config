# @path: ~/projects/nix-config/home-manager/app/wezterm.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.wezterm.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;  # auto (source wezterm.sh)
    enableBashIntegration = true;

    package = let
      core = pkgs.wezterm;
    in pkgs.symlinkJoin {
      name = "wezterm-with-x11-gpu-deps";
      paths = [
        core
        pkgs.mesa
        pkgs.libglvnd
        pkgs.xorg.libX11
        pkgs.xorg.libxcb
        pkgs.libxkbcommon
      ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for bin in $out/bin/wezterm $out/bin/wezterm-gui; do
          if [ -e "$bin" ]; then
            wrapProgram "$bin" --prefix LD_LIBRARY_PATH : ${
              pkgs.lib.makeLibraryPath [
                pkgs.mesa
                pkgs.libglvnd
                pkgs.xorg.libX11
                pkgs.xorg.libxcb
                pkgs.libxkbcommon
              ]
            }
          fi
        done
      '';
    };

    extraConfig = ''
      return {
        font = wezterm.font("JetBrainsMono Nerd Font"),
        font_size = 11.0,
        color_scheme = "Catppuccin-Mocha",
        hide_tab_bar_if_only_one_tab = true,
        enable_tab_bar = false,
        window_padding = { left = 0, right = 0, top = 0, bottom = 0 },
        keys = {
          { key = "Enter", mods = "ALT", action = wezterm.action.ToggleFullScreen },
        },
        -- 可选：启动即进 tmux（推荐）
        -- default_prog = { "zsh", "-l", "-c", "exec tmux new-session -A -s main" },
      }
    '';
  };
}


