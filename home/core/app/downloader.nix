# @path: ~/projects/configs/nix-config/home/core/app/downloader.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::app::downloader


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    # qbittorrent
    # qbittorrent-enhanced

    # Magnet links, torrents, DHT, PEX, crypto
    # transmission_4
    transmission_4-gtk  # gui

    # Sup HTTP/HTTPS/FTP/BT/Magnet
    # - aria2c "magnet:?xt=urn:btih:..."
    # - aria2c https://example.com/file.zip
    aria2
  ];

}


