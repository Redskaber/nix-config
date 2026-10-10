# @path: ~/projects/configs/nix-config/tests/nixos/core/base/portal.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: tests::nixos::core::base::portal
# @source: platform/nixos/core/base/portal.nix, hosts/vm/shared.nix
#
# T7.2 eval-level acceptance of the portal capability gate — the
# export-modules.nix pattern (see tests/nixos/core/base/wsl.nix):
# production modules imported into standalone nixosSystem evaluations,
# contract checks as plain eval-time asserts in the let.
#
# Two evaluations, two laws:
#
#   desktop — the portal module under the ambient base policy
#     (hyprland, desktop-session true): mediation ON, the wm
#     strategy's portals riding (the bare-metal host is untouched by
#     the gate — its closure stays byte-identical).
#
#   console — the REAL vm machine through the customs door (the
#     emitter's own mkShared construction, same loader/args/hostName
#     as lib/shared/targets.nix): post-T7.2 the vm is console-shaped
#     (wm/dm none, debt #6) — the portal gate answers that with zero
#     mediation, the desktop subtraction holds (no hyprland, no DM,
#     no ly), and the machine's own story survives the flip (btrfs
#     ephemeral root, /persistent, the pg server) — the console flip
#     subtracted exactly the desktop stack, nothing else.
#
# Boot-level acceptance of the slimmed vm is the CI vm-tests stage /
# a KVM host (README known-debt #8's environment-gated class); what
# this test pins is the whole subtraction at evaluation depth.

{
  inputs,
  shared,
  pkgs,
  lib,
  ...
}:

let
  nixosSystem = inputs.nixpkgs.lib.nixosSystem;

  # ── desktop: the module under the ambient base policy ──────────
  # The base policy selects hyprland — desktop-session true — so the
  # gate must let the whole portal stack through unchanged.
  desktopEval = nixosSystem {
    specialArgs = {
      inherit inputs;
      # the ambient base policy — platform nixos, wm hyprland
      inherit shared;
    };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      ../../../../platform/nixos/core/base/portal.nix
    ];
  };

  # ── console: the REAL vm machine, the emitter's construction ───
  # Same loader, same args, same hostName as lib/shared/targets.nix
  # mkShared — the policy chain (base shared.nix ⊕ hosts/vm/
  # shared.nix with the T7.2 wm/dm none flip, schema re-validated,
  # runtime IR synthesized) runs here exactly as it does for the
  # flake output; the customs door routes the whole machine (facter
  # data + disko layout + impermanence policy included).
  vmShared = import ../../../../lib/shared {
    inherit (inputs) self nixpkgs nixpkgs-unstable;
    inherit inputs;
    hostName = "vm";
  };

  vmEval = nixosSystem {
    specialArgs = {
      inherit inputs;
      shared = vmShared;
    };
    # Directory reference — the same shape mkNixosSystem emits.
    modules = [ ../../../../platform/nixos ];
  };

  # ── Eval-time assertions ─────────────────────────────────────────
  dcfg = desktopEval.config;
  vmcfg = vmEval.config;

  evalAssertions =
    # desktop law: mediation on, the hyprland strategy riding
    assert dcfg.xdg.portal.enable;
    assert dcfg.xdg.portal.wlr.enable;
    assert dcfg.xdg.portal.extraPortals != [ ];
    # nixpkgs normalizes the default list to a semicolon-joined
    # string ("hyprland;gtk") — assert the resolved shape, the
    # strategy payload riding through it.
    assert dcfg.xdg.portal.config.common.default == "gtk";
    assert dcfg.xdg.portal.config.hyprland.default == "hyprland;gtk";
    # console law: the gate — zero portal mediation on the vm
    assert !vmcfg.xdg.portal.enable;
    # the debt #6 subtraction, verified on the real machine
    assert !vmcfg.programs.hyprland.enable;
    assert !vmcfg.services.displayManager.enable;
    assert !vmcfg.services.displayManager.ly.enable;
    assert !vmcfg.services.xserver.enable;
    # the machine story survives the flip: ephemeral root + pg server
    assert vmcfg.fileSystems."/".fsType == "btrfs";
    assert
      vmcfg.fileSystems."/".options == [
        "x-initrd.mount"
        "defaults"
        "subvol=root"
      ];
    assert vmcfg.environment.persistence ? "/persistent";
    assert vmcfg.services.postgresql.enable;
    "eval-assertions-passed";
in
{
  name = "nixos_core_base_portal";
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

    with subtest("portal: desktop-session gate keeps desktop mediation on and subtracts it from console forms"):
        # ${evalAssertions} — renders only if both forms answered every
        # question this test asks; the machine itself is a dummy.
        machine.succeed("true")
  '';
}
