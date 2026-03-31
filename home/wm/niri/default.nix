# @path: ~/projects/configs/nix-config/home/wm/niri/default.nix
# @author: redskaber
# @datetime: 2026-03-05
# @description: home::wm::niri::default
# @diractory: https://nix-community.github.io/home-manager/options.xhtml
# - niri user custom configurations
# TODO: waiting workspace custom design


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./theme
  ];

  home.packages = with pkgs; [
    # alacritty     # niri default terminal
    kitty           # terminal
    fuzzel          # niri default app nemu
    # swaylock      # niri default window lock, this used swaylock-effetcs
    orca            # niri default window reader
    brightnessctl   # niri default light-changer

    swww
    swaybg
    yad
    hyprpicker
    wf-recorder
    swaynotificationcenter
    wlr-which-key
    wlogout
    python312Packages.toggl-cli

    xwayland-satellite
  ];

  # Used niri config
  xdg.configFile."niri" = {
    source = inputs.niri-config;    # abs path
    recursive = true;               # rec-link
    force = true;
  };

  home.sessionVariables = {
    GDK_BACKEND = "wayland,x11";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    XDG_CURRENT_DESKTOP = "niri";
  };

  systemd.user.services.xwayland-satellite = {
    Unit = {
      Description = "Xwayland outside your Wayland";
      BindsTo = "graphical-session.target";
      PartOf = "graphical-session.target";
      After = "graphical-session.target";
      Requisite = "graphical-session.target";
    };
    Service = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
      StandardOutput = "journal";
    };
    Install.WantedBy = ["niri.service"];
  };

}


