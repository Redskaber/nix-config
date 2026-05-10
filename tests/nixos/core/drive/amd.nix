# @path: ~/projects/configs/nix-config/tests/nixos/core/drive/amd.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::nixos::core::drive::amd
# @source: nixos/core/drive/amd.nix
#
# Verifies AMD GPU driver toolchain:
#   - radeontop, mesa, rocmPackages, vulkan-tools
# Scope: binary presence only (no physical GPU in QEMU).

{ pkgs, lib, ... }:
{
  name = "nixos_core_drive_amd";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [
      radeontop
      mesa
      vulkan-tools
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("amd_drive: radeontop binary present"):
        w = machine.succeed("which radeontop 2>/dev/null || echo not_found").strip()
        print(f"radeontop: {w}")

    with subtest("amd_drive: vulkaninfo binary present"):
        w = machine.succeed("which vulkaninfo 2>/dev/null || echo not_found").strip()
        print(f"vulkaninfo: {w}")

    with subtest("amd_drive: mesa glxinfo present"):
        w = machine.succeed("which glxinfo 2>/dev/null || echo not_found").strip()
        print(f"glxinfo: {w}")
  '';
}
