# @path: ~/projects/configs/nix-config/home/theme/qtct.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::sys::qtct
# - minix(optional mod): qt and gtk theme


{ inputs
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

    catppuccin-qt6ct # qt5ct and qt6ct -> catppuccin
  ];

}


