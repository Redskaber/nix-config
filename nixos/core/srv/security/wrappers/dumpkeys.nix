# @path: ~/projects/configs/nix-config/nixos/core/srv/security/wrappers/dumpkeys.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nixos::core::srv::security::wrappers::dumpkeys


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{

  security.wrappers.dumpkeys = {
    source = "${pkgs.kbd}/bin/dumpkeys";
    owner = "root";
    group = "tty";
    permissions = "u+xs,g+x";
    setuid = true;
  };


}


