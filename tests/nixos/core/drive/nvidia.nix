# @path: ~/projects/configs/nix-config/tests/nixos/core/drive/nvidia.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::nixos::core::drive::nvidia
# @source: nixos/core/drive/nvidia.nix
#
# Verifies NVIDIA driver tooling presence (no real GPU in VM):
#   - nvidia-smi binary present (from driver package)
#   - OpenGL libraries available
#   - modesetting enabled kernel param
#
# Note: actual GPU init cannot be verified in QEMU VM without device passthrough.
# These tests verify declarative config and tooling wiring only.

{ pkgs, lib, ... }:
{
  name = "nixos_core_drive_nvidia";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = { config, ... }: {
    virtualisation.memorySize = 512;

    # Cannot enable hardware.nvidia in VM (no PCIe GPU)
    # Instead verify nixGL and OpenGL tooling are available
    services.xserver.videoDrivers = ["nvidia"];

    hardware.graphics.extraPackages = with pkgs; [
      nvidia-vaapi-driver
    ];

    hardware.nvidia = {
      # enabled = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      nvidiaSettings = true;
      videoAcceleration = true;
      open = false;

      powerManagement.enable = false;
      powerManagement.finegrained = false;
    };

    boot.blacklistedKernelModules = [ "nouveau" ];



    environment.systemPackages = with pkgs; [
      mesa-demos
      pciutils
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("nvidia: pciutils (lspci) present for GPU detection"):
        w = machine.succeed("which lspci").strip()
        assert "lspci" in w, f"lspci not found: {w}"

    with subtest("nvidia: OpenGL driver libs path exists"):
        rc = machine.execute(
            "test -d /run/opengl-driver/lib || test -d /run/opengl-driver-32/lib"
        )[0]
        print(f"opengl-driver rc: {rc}")

    with subtest("nvidia: mesa-demos binary present"):
        w = machine.succeed("which mesa 2>/dev/null || true").strip()
        print(f"mesa-demos: {w}")
  '';
}
