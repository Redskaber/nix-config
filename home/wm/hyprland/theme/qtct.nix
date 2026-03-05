# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/qtct.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::wm::hyprland::theme::qtct
# - minix(optional mod): qt and gtk theme


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    # custom
    # kdePackages.qt6ct
    # libsForQt5.qt5ct

    catppuccin-qt5ct # qt5ct and qt6ct -> catppuccin
  ];

}


