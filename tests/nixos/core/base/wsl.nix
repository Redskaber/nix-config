# @path: ~/projects/configs/nix-config/tests/nixos/core/base/wsl.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: tests::nixos::core::base::wsl
# @source: platform/nixos/core/base/wsl.nix, platform/nixos-wsl/ (the fifth form)
#
# T7.1 eval-level acceptance of the NixOS-WSL fifth system form —
# the export-modules.nix pattern (see tests/nixos/core/base/
# impermanence.nix) applied to a whole platform customs door: the
# production form is imported into standalone nixosSystem
# evaluations, and the contract checks are plain eval-time asserts
# in the let. The form eval speaks the EMITTER's own dialect — the
# real host policy is constructed exactly like targets.nix mkShared
# (same loader, same args, same hostName), so what this test pins is
# the chain an actual nixosConfigurations entry would traverse:
# policy → schema validation → classification fact → customs door.
#
# Two evaluations, two laws:
#
#   form — hosts/nixos-wsl through platform/nixos-wsl/: the WSL
#     interpreter owns its surface (wsl.enable, tarballBuilder, the
#     boot/kernel subtractions), the nixos customs arrive intact
#     (hostName, stateVersion, the user), the form's console shape
#     holds (no DM, no WM, no xserver), and the repo delta (chrony
#     clock-drift guard) is live.
#
#   inert — the delta module under a plain-nixos policy (the
#     ambient base shared, caps.wsl false): ZERO contribution —
#     the "no capability, no effect" law that keeps the module
#     universal across the nixos customs tree.
#
# Boot-level acceptance (importing the built tarball into a real
# WSL2 distro) is the CI vm-tests stage / a Windows host (README
# known-debt #8's environment-gated class); what this test pins is
# everything above import: the form's own evaluation contract.

{
  inputs,
  shared,
  pkgs,
  lib,
  ...
}:

let
  nixosSystem = inputs.nixpkgs.lib.nixosSystem;

  # ── the REAL host policy, the emitter's own construction ──────
  # Same loader, same args, same hostName as lib/shared/targets.nix
  # mkShared — the policy chain (base shared.nix ⊕
  # hosts/nixos-wsl/shared.nix, schema re-validated, runtime IR
  # synthesized) runs here exactly as it does for the flake output.
  wslShared = import ../../../../lib/shared {
    inherit (inputs) self nixpkgs nixpkgs-unstable;
    inherit inputs;
    hostName = "nixos-wsl";
  };

  # ── the form: customs door + real policy + real host data ─────
  formEval = nixosSystem {
    specialArgs = {
      inherit inputs;
      shared = wslShared;
    };
    # Directory reference — the same shape mkNixosSystem emits.
    modules = [ ../../../../platform/nixos-wsl ];
  };

  # ── inert: the delta under a plain-nixos policy ───────────────
  inertEval = nixosSystem {
    specialArgs = {
      inherit inputs;
      # the ambient base policy — platform nixos, caps.wsl false
      inherit shared;
    };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      ../../../../platform/nixos/core/base/wsl.nix
    ];
  };

  # ── Eval-time assertions ─────────────────────────────────────────
  cfg = formEval.config;

  evalAssertions =
    # the interpreter's surface: enabled, addressing OUR user, and
    # owning the WSL artifact (the importable distro tarball)
    assert cfg.wsl.enable;
    assert cfg.wsl.defaultUser == "kilig";
    assert cfg.system.build.tarballBuilder != null;
    # the boot/kernel subtraction (WSL supplies its own)
    assert !cfg.boot.loader.grub.enable;
    assert !cfg.boot.loader.systemd-boot.enable;
    assert !cfg.boot.initrd.enable;
    assert !cfg.boot.kernel.enable;
    assert !cfg.powerManagement.enable;
    # the nixos customs arrived intact through the thin door
    assert cfg.networking.hostName == "nixos-wsl";
    assert cfg.system.stateVersion == "26.05";
    assert cfg.users.users.kilig.isNormalUser;
    # the form's console shape: Null-Object dm/wm rows, no desktop
    # rode along (the base policy's hyprland did NOT leak in)
    assert !cfg.services.displayManager.enable;
    assert !cfg.services.xserver.enable;
    assert !cfg.programs.hyprland.enable;
    # the repo delta is live: the clock-drift guard
    assert cfg.services.chrony.enable;
    # inert: the delta module contributes nothing under a
    # plain-nixos policy (no capability, no effect)
    assert !inertEval.config.services.chrony.enable;
    "eval-assertions-passed";
in
{
  name = "nixos_core_base_wsl";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 60;
  };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("wsl: fifth form evaluates, interpreter owns its surface, delta stays inert without the capability"):
        # ${evalAssertions} — renders only if the form answered every
        # question this test asks; the machine itself is a dummy.
        machine.succeed("true")
  '';
}
