# @path: ~/projects/configs/nix-config/home/core/exp/sys/shell/default.nix
# @author: redskaber
# @datetime: 2026-03-04
# @description: home::core::exp::sys::shell::default
#
# Routing mode (mode A: single-select routing):
#   Selects shell module based on shared.user.shell.tag.
#   Consistent with nixos/wm/default.nix and nixos/dm/default.nix.


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./${shared.user.shell.tag}.nix
  ];
}
