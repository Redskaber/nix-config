# @path: ~/projects/configs/nix-config/nixos/core/srv/mysql.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: nixos::core::srv::mysql - 本地 MySQL 服务配置 (开发环境)

{ inputs
, lib
, config
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [ mysql84 ];

}


