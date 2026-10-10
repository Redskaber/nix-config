# @path: ~/projects/configs/nix-config/platform/nixos/core/base/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::base::default

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./bluetooth.nix
    ./boot.nix
    # Disk-layout interpreter registration (T5.13) — capability here,
    # layouts as host facts in hosts/<h>/disk.nix.
    ./disk.nix
    # Ephemeral-root / persistence interpreter registration (T5.14) —
    # capability here, state strategy as host facts in
    # hosts/<h>/persist.nix.
    ./impermanence.nix
    # hardware.nix moved to hosts/${shared.hostName}/hardware.nix (multi-host support)
    ./i18n.nix
    ./memory.nix
    ./network.nix
    ./nix.nix
    ./portal.nix
    ./sound.nix
    ./systemd.nix
    ./user.nix
    ./virtual.nix
    # WSL2 system declaration (T3.1) — mkIf shared.caps.wsl inside (T4.0).
    ./wsl.nix
  ];

}
