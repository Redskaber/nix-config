# @path: ~/projects/configs/nix-config/home/wm/hyprland/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml
# @depends:
# - rofi, waybar, hypr, swaync, ...

{ inputs
, lib
, config
, pkgs
, ...
}:
{
  # nixos manager
  # programs.hyprland.enable = true;
  home.packages = with pkgs; [
    # Hyprland Stuff
    hypridle
    hyprpolkitagent
    pyprland
    #uwsm
    hyprlang
    hyprshot
    hyprcursor
    nwg-displays
    nwg-look
    # base
    waypaper
    waybar
    hyprland-qt-support # for hyprland-qt-support
    rofi
    slurp
    swappy
    swaynotificationcenter
    wallust
    wlogout
    (inputs.ags.packages.${pkgs.stdenv.hostPlatform.system}.default)

    swww
    grimblast
    hyprpicker
    grim
    slurp
    wl-clip-persist
    cliphist
    wf-recorder
  ];

  # hyprland through system enable
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd = {
      enable = true;
      enableXdgAutostart = true;    # auto-enable: ~/.config/autostart/
    };
  };

  xdg.configFile."hypr" = {
    source = inputs.hypr-config;    # abs path
    recursive = true;               # rec-link
    force = true;
  };


}


