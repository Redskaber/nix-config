# @path: ~/projects/configs/nix-config/home/core/exp/sys/media/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::media::default

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./ffmpeg.nix
    ./mpv.nix
  ];

}


