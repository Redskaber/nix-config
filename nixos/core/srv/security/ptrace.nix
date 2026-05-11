# @path: ~/projects/configs/nix-config/nixos/core/srv/security/ptrace.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nixos::core::srv::security::ptrace
# Note:
#   ptrace_scope=0: any process may ptrace same-uid processes.
#   Standard configuration for game hacking / RE on single-user desktops.
#   Not recommended for server environments.

{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 0;

}


