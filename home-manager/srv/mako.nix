# @path: ~/projects/configs/nix-config/home-manager/srv/mako.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-services.mako.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  services.mako = {
    # enable = true;
    settings = {
      # global
      font = "JetBrainsMono Nerd Font 10";
      background-color = "#1e1e2e";
      text-color = "#cdd6f4";
      border-color = "#89b4fa";
      border-radius = 8;
      margin = "10,10,10,10";  # top,right,bottom,left
      padding = "10,10";
      default-timeout = 5000;  # show 5s
      layer = "overlay";       # show top layer (Wayland)
      icons = true;

      # Optional: urgency group css
      "urgency=low" = {
        background-color = "#313244";  # surface0 with transparency
      };
      "urgency=normal" = {
        background-color = "#1e1e2e";  # base with transparency
      };
      "urgency=critical" = {
        background-color = "#eba0ac";
        text-color = "#111111";
        default-timeout = 0;  # don't auto shadow
      };
    };
  };
}
