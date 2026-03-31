# @path: ~/projects/configs/nix-config/home/wm/hyprland/theme/satty.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::wm::hyprland::theme::satty
# - edit screenshot and label tag


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  home.packages = with pkgs; [
    satty  # 截图编辑
    grim   # 截图后端
    slurp  # 区域选择
  ];

}


