# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/rbw.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::rbw
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.rbw.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  programs.rbw = {
    enable = true;
    settings = {
      # core config
      email = shared.rbw.email;
      lock_timeout = shared.rbw.lock_timeout; # sec

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


