# @path: ~/projects/configs/nix-config/home/core/sys/ffmpeg.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: home::core::sys::ffmpeg
# @directory: https://github.com/NixOS/nixpkgs/blob/nixos-25.11/pkgs/development/libraries/ffmpeg/generic.nix?spm=5176.28103460.0.0.10d66308xJqRI6&file=generic.nix


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  home.packages = with pkgs; [ ffmpeg-full ];

}


