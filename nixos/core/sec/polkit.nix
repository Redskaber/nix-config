# @path: ~/projects/configs/nix-config/nixos/core/sec/polkit.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::sec::polkit


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  security = {
    polkit.enable = true;
    polkit.extraConfig = ''
       polkit.addRule(function(action, subject) {
         if (
            subject.isInGroup("users") &&
            subject.active == true &&
            subject.local == true &&
            (
               action.id == "org.freedesktop.login1.reboot" ||
               action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
               action.id == "org.freedesktop.login1.power-off" ||
               action.id == "org.freedesktop.login1.power-off-multiple-sessions"
             )
           )
         {
           return polkit.Result.YES;
         }
      })
    '';
  };


}


