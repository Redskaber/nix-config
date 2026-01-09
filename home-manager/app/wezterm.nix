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
    # enable = true;
    enableZshIntegration = true;  # auto (source wezterm.sh)
    enableBashIntegration = true;

    # wayland-config
    # etc.

    # x11-config
    # package = let
    #   core = pkgs.wezterm;
    # in pkgs.symlinkJoin {
    #   name = "wezterm-with-x11-gpu-deps";
    #   paths = [
    #     core
    #     pkgs.mesa
    #     pkgs.libglvnd
    #     pkgs.xorg.libX11
    #     pkgs.xorg.libxcb
    #     pkgs.libxkbcommon
    #   ];
    #   buildInputs = [ pkgs.makeWrapper ];
    #   postBuild = ''
    #     for bin in $out/bin/wezterm $out/bin/wezterm-gui; do
    #       if [ -e "$bin" ]; then
    #         wrapProgram "$bin" --prefix LD_LIBRARY_PATH : ${
    #           pkgs.lib.makeLibraryPath [
    #             pkgs.mesa
    #             pkgs.libglvnd
    #             pkgs.xorg.libX11
    #             pkgs.xorg.libxcb
    #             pkgs.libxkbcommon
    #           ]
    #         }
    #       fi
    #     done
    #   '';
    # };
  };

  # Used user config:
  xdg.configFile."wezterm" = {
    source = inputs.wezterm-config;   # abs path
    recursive = true;                 # rec-link
    force = true;
  };
}


