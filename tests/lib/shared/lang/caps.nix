# @path: ~/projects/configs/nix-config/tests/lib/shared/lang/caps.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::lib::shared::lang::caps
# @source: lib/shared/lang/enum.nix (platform dispatch table)
#
# T4.0 (dispatch-layer convergence): the platform enum is now a
# capability table — THE distribution layer for platform semantics.
# This contract test locks the table itself:
#
#   1. exhaustivity — every platform row answers every capability
#      dimension (adding a dimension forces every row to answer it,
#      like nix-types match; adding a platform forces a full row)
#   2. the truth table — linux-family / nixos-system / wsl / darwin
#   3. strategy lambdas — btop (GPU-stack on Linux family, stock on
#      darwin) and trace-tools (five tools vs Null-Object empty list),
#      applied to marker scopes so selections are asserted by VALUE
#   4. window-manager capability bits (desktop-session) — the
#      Null-Object row must stay the only false one
#   5. shell integration payload rows (T4.1) — every variant answers
#      all three HM integration bits; the payload table replaced the
#      runtime layer's three `.tag ==` comparisons
#
# Mutating any row (e.g. flipping darwin linux-family to true, pointing
# the darwin btop row at the GPU build, or flipping the zsh row's
# enableZshIntegration) turns this check red at eval time — before any
# VM boots.

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # ── REAL production import (no mocks, no copies) ──────────────────
  realEnum = import ../../../../lib/shared/lang/enum.nix { inherit inputs; };

  dims = [
    "linux-family"
    "nixos-system"
    "wsl"
    "darwin"
  ];
  allPlatforms = with realEnum.platform; [
    linux
    darwin
    nixos
    wsl
  ];

  # Marker scopes: strategy lambdas must be selection functions, so the
  # test asserts what they SELECT, not just that they are functions.
  gpuMarker = {
    btop = {
      override = args: args;
    };
  };
  stockMarker = {
    btop = "STOCK-BTOP";
  };
  traceScope = {
    valgrind = "valgrind";
    strace = "strace";
    ltrace = "ltrace";
    pciutils = "pciutils";
    vulkan-tools = "vulkan-tools";
  };

  # ── Eval-time assertions (fail the check build, not just the VM) ──
  evalAssertions =
    # 1. every row answers every dimension (exhaustive by construction)
    assert builtins.all (p: builtins.all (d: p.value.caps ? ${d}) dims) allPlatforms;
    # 2. the truth table — one assertion per cell that matters
    assert realEnum.platform.linux.value.caps.linux-family;
    assert realEnum.platform.nixos.value.caps.linux-family;
    assert realEnum.platform.wsl.value.caps.linux-family;
    assert !realEnum.platform.darwin.value.caps.linux-family;
    assert realEnum.platform.nixos.value.caps.nixos-system;
    assert !realEnum.platform.linux.value.caps.nixos-system;
    assert !realEnum.platform.wsl.value.caps.nixos-system;
    assert !realEnum.platform.darwin.value.caps.nixos-system;
    assert realEnum.platform.wsl.value.caps.wsl;
    assert !realEnum.platform.nixos.value.caps.wsl;
    assert realEnum.platform.darwin.value.caps.darwin;
    assert !realEnum.platform.nixos.value.caps.darwin;
    # 3a. btop strategy: Linux family selects the GPU-stack build,
    #     darwin selects stock — asserted by VALUE through markers.
    assert
      realEnum.platform.nixos.value.btop gpuMarker == {
        rocmSupport = true;
        cudaSupport = true;
      };
    assert
      realEnum.platform.linux.value.btop gpuMarker == {
        rocmSupport = true;
        cudaSupport = true;
      };
    assert
      realEnum.platform.wsl.value.btop gpuMarker == {
        rocmSupport = true;
        cudaSupport = true;
      };
    assert realEnum.platform.darwin.value.btop stockMarker == "STOCK-BTOP";
    # 3b. trace-tools: five tools on the Linux family, Null-Object
    #     empty list on darwin (absence expressed as a value).
    assert
      realEnum.platform.nixos.value.trace-tools traceScope == [
        "valgrind"
        "strace"
        "ltrace"
        "pciutils"
        "vulkan-tools"
      ];
    assert realEnum.platform.darwin.value.trace-tools traceScope == [ ];
    # 3c. home-prefix rows feed fn.homeDir (interpolation, not branch)
    assert realEnum.platform.darwin.value.home-prefix == "/Users";
    assert builtins.all (p: p.value.home-prefix == "/home") (
      with realEnum.platform;
      [
        linux
        nixos
        wsl
      ]
    );
    # 4. window-manager capability bits: only the Null-Object row has
    #    no desktop session (portal/i18n gates consume this fact).
    assert realEnum.window-manager.hyprland.value.desktop-session;
    assert realEnum.window-manager.niri.value.desktop-session;
    assert realEnum.window-manager.gnome.value.desktop-session;
    assert !realEnum.window-manager.none.value.desktop-session;
    # 5. shell integration rows (T4.1): every variant answers all three
    #    bits — exhaustive by construction, like the caps vectors. The
    #    runtime layer publishes these verbatim as shellIntegrations.
    assert builtins.all
      (
        s:
        builtins.all (k: s.value.integrations ? ${k}) [
          "enableBashIntegration"
          "enableZshIntegration"
          "enableFishIntegration"
        ]
      )
      (
        with realEnum.shell;
        [
          bash
          zsh
          fish
        ]
      );
    assert realEnum.shell.zsh.value.integrations.enableZshIntegration;
    assert !realEnum.shell.zsh.value.integrations.enableBashIntegration;
    assert !realEnum.shell.zsh.value.integrations.enableFishIntegration;
    assert realEnum.shell.bash.value.integrations.enableBashIntegration;
    assert !realEnum.shell.bash.value.integrations.enableZshIntegration;
    assert realEnum.shell.fish.value.integrations.enableFishIntegration;
    assert !realEnum.shell.fish.value.integrations.enableZshIntegration;
    "eval-assertions-passed";
in
{
  name = "lib_shared_lang_caps";
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

    with subtest("caps: dispatch table exhaustivity + truth table + strategies"):
        # ${evalAssertions} — if this line renders, the platform
        # dispatch table still answers every question the leaves ask.
        machine.succeed("true")
  '';
}
