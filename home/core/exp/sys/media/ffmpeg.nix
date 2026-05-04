# @path: ~/projects/configs/nix-config/home/core/exp/sys/media/ffmpeg.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::media::ffmpeg
# @directory: https://github.com/NixOS/nixpkgs/blob/nixos-25.11/pkgs/development/libraries/ffmpeg/generic.nix?spm=5176.28103460.0.0.10d66308xJqRI6&file=generic.nix


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [ ffmpeg-full ];

}


