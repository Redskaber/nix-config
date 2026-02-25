# @path: ~/projects/configs/nix-config/nixos/core/srv/security/keyring.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::security::keyring
# - gnupg: https://search.nixos.org/options?channel=25.11&query=programs.gnupg
# - gnome-keyring: https://search.nixos.org/options?channel=25.11&query=services.gnome.gnome-keyring
# @usage:
# - terminal: pinentry-curses
# - gnome: pinentry-gnome3
# - hyprland: pinentry-bemenu


{ inputs
, config
, lib
, pkgs
, ...
}:
{

  environment.systemPackages = with pkgs; [ gnupg ];

  programs.gnupg = {
    package = pkgs.gnupg;
    agent = {
      enable = true;
      enableSSHSupport = true;
      enableExtraSocket = false;
      enableBrowserSocket = false;
      pinentryPackage = pkgs.pinentry-curses;
      # 参考: NIST SP 800-63B 建议 ≤ 15min，桌面体验可适度放宽
      # ssettings
    };
    dirmngr.enable = true;
  };

  # only gnome used
  # services.gnome.gnome-keyring.enable = true;

}


