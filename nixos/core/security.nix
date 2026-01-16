# @path: ~/projects/configs/nix-config/nixos/core/security.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::security


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  # Security / Polkit
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
  security.pam.services.swaylock = {
    text = ''
      auth include login
    '';
  };

}


