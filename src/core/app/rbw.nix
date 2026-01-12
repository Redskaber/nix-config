# @path: ~/projects/configs/nix-config/src/core/app/rbw.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/src/options.xhtml#opt-programs.rbw.enable


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
      # - nix search nixpkgs pinentry
      #
      pinentry = pkgs.pinentry-gtk2;
    };
  };

}


