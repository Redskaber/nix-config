# @path: ~/projects/configs/nix-config/home/core/sys/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::sys::default



{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  imports = [
    ./atuin.nix
    ./bat.nix
    ./bottom.nix
    ./btop.nix
    ./compat.nix
    ./compress.nix
    ./debug.nix
    ./direnv.nix
    ./duf.nix
    ./eza.nix
    ./fastfetch.nix
    ./fd.nix
    ./ffmpeg.nix
    ./fish.nix
    ./fonts.nix
    ./fzf.nix
    ./git.nix
    ./htop.nix
    ./i18n.nix
    ./jq.nix
    ./just.nix
    ./netutils.nix
    ./portal.nix
    ./ripgrep.nix
    ./security.nix
    ./starship.nix
    ./wl-clipboard.nix
    ./zoxide.nix
    ./zsh.nix
  ];


}


