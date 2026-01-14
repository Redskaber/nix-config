# @path: ~/projects/configs/nix-config/src/wm/hyprland/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml
# @depends:
# - ghostty
# - rofi
# - nemo
# - zen-browser


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./hyprland.nix
    ./exec-once.nix
    ./monitor.nix
    ./setting.nix
    ./bind.nix
    ./window-rule.nix
    ./hyprlock.nix
    ./variable.nix
  ];

}


