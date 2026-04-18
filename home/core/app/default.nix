# @path: ~/projects/configs/nix-config/home/core/app/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::app::default



{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./ai
    ./browser
    ./game
    ./img
    ./music
    ./office
    ./re
    ./yazi

    ./baidupcs-go.nix
    # ./cava.nix
    ./discord.nix
    ./downloader.nix
    ./emacs.nix
    ./kiro.nix
    ./kitty.nix
    ./lutris.nix
    ./mpv.nix
    ./nemo.nix
    ./nvim.nix
    ./obsidian.nix
    ./qq.nix
    ./rbw.nix
    ./tealdeer.nix
    ./tmux.nix
    ./vscode.nix
    ./wechat.nix
    ./wezterm.nix
    ./xunlei.nix
    ./zed.nix
  ];


}


