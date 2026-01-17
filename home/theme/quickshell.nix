# @path: ~/projects/configs/nix-config/home/theme/quickshell.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.quickshell.enable
# @discription: home::theme::quickshell
# - desctop ui, panel, launcher, system-pq, note-center


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Qt6 dependencies for quickshell
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    qt6.qtsvg
    qt6.qtmultimedia
  ];

  xdg.configFile."quickshell" = {
    source = inputs.quickshell-config;    # abs path
    recursive = true;                     # rec-link
    force = true;
  };

}


