# @path: ~/projects/configs/nix-config/platform/nixos/system/core/base/wsl.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: platform::nixos::core::base::wsl — NixOS-WSL system deltas
# @directory: https://github.com/nix-community/NixOS-WSL
#
# The system-domain WSL module — the TRUE DELTA only. The upstream
# NixOS-WSL interpreter (imported by platform/nixos-wsl/system) OWNS
# the WSL surface: wsl.conf generation, systemd hosting,
# interop/binfmt and the boot/kernel/loader subtraction (WSL supplies
# its own). What stays here is exactly what upstream does NOT ship
# and this repo still wants — one item:
#
#   chrony — the dual-kernel clock-drift guard. WSL disables
#     systemd-timesyncd (the VM's root namespace runs its own
#     chronyd), and the classic WSL2 failure mode is a clock that
#     drifts after the Windows host sleeps; a distro-side chrony
#     keeps the shared kernel clock honest.
#
# The activation gate is shared.caps.wsl — false on every
# plain-nixos host (this module is a no-op there); the nixos-wsl
# row answers it true.
#
# The user-domain half of the WSL specialisation (wslview, WSLENV)
# lives in home/core/base/wsl.nix — also caps.wsl-gated, shared by
# the standalone-wsl and nixos-wsl hosts.

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf shared.caps.wsl {
    # WSL2 clock skew guard: chrony syncs against external NTP after
    # host resume (dual-kernel time drift is a classic WSL issue;
    # upstream leaves distro-side NTP to the host operator).
    services.chrony = {
      enable = lib.mkDefault true;
      servers = [
        "time.cloudflare.com"
        "time.aws.com"
      ];
    };
  };
}
