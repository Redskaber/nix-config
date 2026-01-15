# @path: ~/projects/configs/nix-config/home/core/app/kitty.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.kitty.enable


{ inputs
, lib
, config
, pkgs
, ...
}:
let
  kitty_path = "${config.home.profileDirectory}/bin/kitty";
in
{

  programs.kitty = {
    enable = true;
    package = config.lib.nixGL.wrap pkgs.kitty;
  };

  # Used user config:
  xdg.configFile."kitty" = {
    source = inputs.kitty-config;   # abs path
    recursive = true;               # rec-link
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


