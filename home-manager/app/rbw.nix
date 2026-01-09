# @path: ~/projects/configs/nix-config/home-manager/app/rbw.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.rbw.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.rbw = {
    enable = true;
    settings = {
      # core config
      email = "alexredskaber@gmail.com";
      lock_timeout = 600; # sec

      # server config
      # base_url = "https://vault.yourdomain.com";
      # identity_url = "https://vault.yourdomain.com/identity";

      # pinentry: input main pwd
      # choice desktop wm:
      # - GNOME: pkgs.pinentry-gnome3
      # - KDE: pkgs.pinentry-qt
      # - normal/terminal: pkgs.pinentry-tty
      # - remaind：pkgs.pinentry

      # auto fallback -> backend
      pinentry = pkgs.pinentry;
    };
  };

}


