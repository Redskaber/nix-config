# @path: ~/projects/configs/nix-config/nixos/core/srv/security/keyring.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::security::keyring
# - gnupg: https://search.nixos.org/options?channel=25.11&query=programs.gnupg
# - gnome-keyring: https://search.nixos.org/options?channel=25.11&query=services.gnome.gnome-keyring

{ inputs
, config
, lib
, pkgs
, ...
}:
{

  programs.gnupg = {
    package = pkgs.gnupg;
    agent = {
      enable = true;
      enableSSHSupport = true;
      enableExtraSocket = false;
      enableBrowserSocket = false;
      pinentryPackage = pkgs.pinentry-curses;
      # 参考: NIST SP 800-63B 建议 ≤ 15min，桌面体验可适度放宽
      settings = {
        default-cache-ttl = 600;          # 30分钟（日常操作舒适区）
        max-cache-ttl = 3600;             # 1小时（防长时间离席风险）
        allow-loopback-pinentry = false;  # 默认即 false，显式注释说明
      };
    };
    dirmngr.enable = false;
  };

  services = {
    gnome.gnome-keyring.enable = true;
  };

}


