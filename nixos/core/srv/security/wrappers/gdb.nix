# @path: ~/projects/configs/nix-config/nixos/core/srv/security/wrappers/gdb.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nixos::core::srv::security::wrappers::gdb
# Note:
#   pince hardcodes /bin/gdb and calls `sudo gdb` via pexpect.
#   - systemd.tmpfiles: exposes /bin/gdb for tools expecting FHS layout.
#   - sudo.extraRules: NOPASSWD covers all /nix/store/*/bin/gdb variants
#     since pince's bundled gdb path differs from pkgs.gdb at runtime.

{ inputs, shared, config, lib, pkgs, ... }:
{
  systemd.tmpfiles.rules = [
    "L+ /bin/gdb - - - - ${pkgs.gdb}/bin/gdb"
  ];

  security.sudo.extraRules = [
    {
      users = [ shared.user.username ];
      commands = [
        { command = "/bin/gdb";                        options = [ "NOPASSWD" "SETENV" ]; }
        { command = "/run/current-system/sw/bin/gdb";  options = [ "NOPASSWD" "SETENV" ]; }
        { command = "/nix/store/*/bin/gdb";            options = [ "NOPASSWD" "SETENV" ]; }
      ];
    }
  ];
}
