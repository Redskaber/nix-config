# @path: ~/projects/configs/nix-config/nixos/core/driver.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::driver


{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  # TODO: waiting auto dispatch
  imports = [
    ./amd.nix
    ./intel.nix
    ./nvidia.nix
    ./nvidia-prime.nix
  ];

}


