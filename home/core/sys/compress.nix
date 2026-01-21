# @path: ~/projects/configs/nix-config/home/core/sys/compress.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: home::core::sys::compress


{ inputs
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    zip
    unzip
    gnutar
    gzip
    bzip2
    xz
    p7zip
    unrar
    zstd
    lzip
    lz4
  ];
}


