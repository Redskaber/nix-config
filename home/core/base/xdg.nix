# @path: ~/projects/configs/nix-config/home/core/base/xdg.nix
# @author: redskaber
# @datetime: 2026-07-16
# @description: home::core::base::xdg
# @directory: https://nix-community.github.io/home-manager/options/home-manager/xdg.html

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  xdg = {
    enable = true;   # XDG Base Directory std (config: ~/.config; data: ~/.local/share)

    # XDG user directories
    userDirs = {
      package = shared.pkgs.xdg-user-dirs;
      enable = true;             # gen ~/.config/user-dirs.dirs
      createDirectories = true;  # autocreate dir (not exist)
      # home.homeDirectory（host/* define）
      desktop     = "${config.home.homeDirectory}/${shared.const.xdg.userDirs.desktop}";
      documents   = "${config.home.homeDirectory}/${shared.const.xdg.userDirs.documents}";
      download    = "${config.home.homeDirectory}/${shared.const.xdg.userDirs.download}";
      music       = "${config.home.homeDirectory}/${shared.const.xdg.userDirs.music}";
      pictures    = "${config.home.homeDirectory}/${shared.const.xdg.userDirs.pictures}";
      videos      = "${config.home.homeDirectory}/${shared.const.xdg.userDirs.videos}";
      # publicShare = "${config.home.homeDirectory}/Public";
      # templates   = "${config.home.homeDirectory}/Templates";
      extraConfig = {
        # extra dir mapping
      };
    };

    # Options
    # configFile  = { };   # link to ~/.config/<name>
    # dataFile    = { };   # use ~/.local/share/<name>
    # cacheFile   = { };   # use ~/.cache/<name>
  };
}

