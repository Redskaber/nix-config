# @path: ~/projects/configs/nix-config/platform/nixos/dm/lemurs/default.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: platform::nixos::dm::lemurs::default

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  services.displayManager = {
    enable = true;
    lemurs = {
      enable = true;
      package = pkgs.lemurs;
      # settings = {};
    };
  };

}
