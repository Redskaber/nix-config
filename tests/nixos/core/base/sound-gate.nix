# @path: ~/projects/configs/nix-config/tests/nixos/core/base/sound-gate.nix
# @author: redskaber
# @datetime: 2026-10-11
# @description: tests::nixos::core::base::sound-gate
# @source: platform/nixos/core/base/sound.nix, lib/shared/lang/enum.nix
#
# T10.1 eval-level acceptance of the sound strategy gate — the
# export-modules.nix pattern (see tests/nixos/core/base/wsl.nix and
# the portal test): production modules imported into standalone
# nixosSystem evaluations, contract checks as plain eval-time
# asserts in the let.
#
# Two evaluations, two laws:
#
#   pipewire — the module under the ambient base policy (sound =
#     pipewire, the workstation default every current host
#     inherits): the whole stack rides — server, compat layers,
#     rtkit, alsa persistence, the mixer toolbelt. This is the
#     zero-drift law: the gate changed nothing for the forms that
#     keep the default (mkIf true ≡ identity, the T7.2 precedent).
#
#   none — the same module under a sound=none policy. No host flips
#     the row yet (README known-debt #9: the real-machine
#     adjudication — QEMU audio devices, WSLg's Windows-side pulse
#     server — is deliberately env-gated), so unlike the portal
#     test, which borrowed the real vm machine, this form is
#     constructed here through the same wholesale-row grammar
#     hosts/<h>/shared.nix speaks (shared // { sound = …; } — a
#     top-level enum replaced whole, exactly what the loader's
#     shallow merge does). The law: the WHOLE stack subtracts —
#     no server, no compat layers, no rtkit, no persistence, no
#     mixers — proving the flip path a console host will take is
#     one data row, not an edit to the interpreter.

{
  inputs,
  shared,
  pkgs,
  lib,
  ...
}:

let
  nixosSystem = inputs.nixpkgs.lib.nixosSystem;

  # ── pipewire form: the module under the ambient base policy ────
  pipewireEval = nixosSystem {
    specialArgs = {
      inherit inputs;
      # the ambient base policy — sound pipewire (the default row)
      inherit shared;
    };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      ../../../../platform/nixos/core/base/sound.nix
    ];
  };

  # ── none form: the same module under a sound=none policy ───────
  noneShared = shared // {
    sound = shared.enum.sound.none;
  };
  noneEval = nixosSystem {
    specialArgs = {
      inherit inputs;
      shared = noneShared;
    };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      ../../../../platform/nixos/core/base/sound.nix
    ];
  };

  pcfg = pipewireEval.config;
  ncfg = noneEval.config;

  # Name-based membership: robust across pkgs instances (the eval's
  # own import vs the test harness's — derivation identity is not
  # comparable across them; pname is).
  hasPkg = name: list: builtins.any (p: (p.pname or p.name or "") == name) list;

  evalAssertions =
    # enum law: every row answers the capability bit AND the toolbelt
    # (the exhaustive-by-construction property — a row that stops
    # answering a dimension fails HERE, not as a mysterious closure
    # drift).
    assert shared.enum.sound.pipewire.value.sound-server;
    assert !shared.enum.sound.none.value.sound-server;
    assert (shared.enum.sound.pipewire.value.mixers pkgs) != [ ];
    assert (shared.enum.sound.none.value.mixers pkgs) == [ ];
    # the ambient base policy carries the default row (the schema
    # now REQUIRES it — this is the declaration the loader validates)
    assert shared.sound.tag == "pipewire";
    # pipewire form law: the full stack rides
    assert pcfg.services.pipewire.enable;
    assert pcfg.services.pipewire.alsa.enable;
    assert pcfg.services.pipewire.alsa.support32Bit;
    assert pcfg.services.pipewire.pulse.enable;
    assert pcfg.services.pipewire.wireplumber.enable;
    assert pcfg.security.rtkit.enable;
    assert pcfg.hardware.alsa.enablePersistence;
    assert !pcfg.services.pulseaudio.enable;
    assert hasPkg "pamixer" pcfg.environment.systemPackages;
    assert hasPkg "pavucontrol" pcfg.environment.systemPackages;
    # none form law: the whole stack subtracts
    assert !ncfg.services.pipewire.enable;
    assert !ncfg.services.pipewire.alsa.enable;
    assert !ncfg.services.pipewire.pulse.enable;
    assert !ncfg.services.pipewire.wireplumber.enable;
    assert !ncfg.security.rtkit.enable;
    assert !ncfg.hardware.alsa.enablePersistence;
    assert !ncfg.services.pulseaudio.enable;
    assert !(hasPkg "pamixer" ncfg.environment.systemPackages);
    assert !(hasPkg "pavucontrol" ncfg.environment.systemPackages);
    "eval-assertions-passed";
in
{
  name = "nixos_core_base_sound_gate";
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

    with subtest("sound-gate: pipewire form keeps the stack on; none form subtracts it whole"):
        # ${evalAssertions} — renders only if both forms answered every
        # question this test asks; the machine itself is a dummy.
        machine.succeed("true")
  '';
}
