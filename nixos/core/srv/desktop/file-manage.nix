# @path: ~/projects/configs/nix-config/nixos/core/srv/desktop/file-manage.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::desktop::file-manage


{ inputs
, config
, lib
, pkgs
, ...
}:
{

  services = {
    # Preview and remote support
    gvfs.enable = true;
    tumbler.enable = true;
  };


}


