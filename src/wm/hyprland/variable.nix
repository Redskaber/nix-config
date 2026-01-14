# @path: ~/projects/configs/nix-config/src/wm/hyprland/variable.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.sessionVariables = {
    # Wayland
    NIXOS_OZONE_WL = "1";
    GDK_BACKEND = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";

    # Qt
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_QPA_PLATFORM = "wayland";
    # QT_QPA_PLATFORMTHEME = "qt6ct";  # qt6ct
    QT_STYLE_OVERRIDE = "kvantum";     # kvantum

    # GTK
    GTK_THEME = "Colloid-Green-Dark-Gruvbox";

    # NVIDIA / GPU workarounds
    __GL_GSYNC_ALLOWED = "0";
    __GL_VRR_ALLOWED = "0";
    WLR_NO_HARDWARE_CURSORS = "1";

    # 其他
    ANKI_WAYLAND = "1";
    DIRENV_LOG_FORMAT = "";
    GRIMBLAST_HIDE_CURSOR = "0";

    # (Remaind)
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";

    # SSH
    SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent";
  };
}


