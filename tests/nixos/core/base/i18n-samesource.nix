# @path: ~/projects/configs/nix-config/tests/nixos/core/base/i18n-samesource.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::nixos::core::base::i18n-samesource
# @source: lib/shared/shared/fn.nix, nixos/core/base/i18n.nix
#
# T2.6 acceptance: "mixed-source combinations abort at EVAL time."
#
#   1. fn.sameSource unit contract — passes equal fingerprints, throws
#      on mixed ones (with the 995d8c9 reference in the message).
#   2. the production module wiring — declaring i18n.nixpkgs-source =
#      "unstable" while the daemon scope stays stable aborts the import
#      itself (tryEval catches it); the declared-stable wiring keeps
#      producing the single-sourced addon set.
#
# The mixed-source regression class (stable daemon + unstable addons)
# is now impossible to commit silently: it dies before any VM boots.

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # ── REAL production fn.nix (phase-1 pure) ─────────────────────────
  realFn = import ../../../../lib/shared/shared/fn.nix {
    inputs = { };
    enum = { };
    const = { };
    schema = { };
  };

  # Fingerprint-carrying scopes (what the guard actually compares).
  stableScope = {
    lib.trivial.version = "26.05-stable";
  };
  unstableScope = {
    lib.trivial.version = "26.11pre-mock";
  };

  # ── Marker package sets with fingerprints ─────────────────────────
  markPkgs = prefix: fpVersion: {
    lib.trivial.version = fpVersion;
    fcitx5-rime = "${prefix}:fcitx5-rime";
    fcitx5-gtk = "${prefix}:fcitx5-gtk";
    fcitx5-nord = "${prefix}:fcitx5-nord";
    catppuccin-fcitx5 = "${prefix}:catppuccin-fcitx5";
    noto-fonts-color-emoji = "${prefix}:noto-fonts-color-emoji";
    noto-fonts-cjk-sans = "${prefix}:noto-fonts-cjk-sans";
    nerd-fonts = {
      jetbrains-mono = "${prefix}:nerd-fonts.jetbrains-mono";
    };
    qt6Packages = {
      fcitx5-qt = "${prefix}:fcitx5-qt";
      fcitx5-chinese-addons = "${prefix}:fcitx5-chinese-addons";
      fcitx5-configtool = "${prefix}:fcitx5-configtool";
    };
  };

  stablePkgs = markPkgs "STABLE" "26.05-stable";
  unstablePkgs = markPkgs "UNSTABLE" "26.11pre-mock";

  mockShared = declared: {
    upkgs = unstablePkgs;
    pkgs = stablePkgs;
    # T4.0: the runtime layer resolves the declared scope once
    # (shared.i18nScope); the mock mirrors that single resolution.
    i18nScope = if declared == "unstable" then unstablePkgs else stablePkgs;
    fn = realFn;
    time = {
      timeZone = "Asia/Shanghai";
      used-ip-timeZone = false;
    };
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocales = "zh_CN.UTF-8";
      extraLocalSetting = "zh_CN.UTF-8";
      nixpkgs-source = declared;
    };
  };

  importProduction =
    shared:
    import ../../../../nixos/core/base/i18n.nix {
      inputs = { };
      inherit shared lib;
      config = { };
      pkgs = stablePkgs; # the daemon scope: module-system pkgs, stable
    };

  # production wiring: declared stable → single-sourced addon set
  good = (importProduction (mockShared "stable")).i18n.inputMethod.fcitx5.addons;

  # ── Eval-time assertions ──────────────────────────────────────────
  evalAssertions =
    # unit contract: same fingerprint passes through
    assert realFn.sameSource "unit-same" stableScope stableScope == stableScope;
    assert realFn.pkgsFingerprint stableScope == "26.05-stable";
    # unit contract: mixed fingerprint throws
    assert !(builtins.tryEval (realFn.sameSource "unit-mixed" stableScope unstableScope)).success;
    # production wiring: declared stable → single-sourced addon set
    assert builtins.all (a: lib.hasPrefix "STABLE:" (builtins.toString a)) good;
    assert builtins.any (a: lib.hasPrefix "STABLE:fcitx5-chinese-addons" (builtins.toString a)) good;
    # production wiring: declared unstable while daemon is stable →
    # forcing the addon ELEMENTS aborts (T2.6: mixed source dies at eval
    # time — and every real consumer of the list forces its elements)
    assert
      !(builtins.tryEval (
        builtins.deepSeq ((importProduction (mockShared "unstable")).i18n.inputMethod.fcitx5.addons) null
      )).success;
    "eval-assertions-passed";
in
{
  name = "nixos_core_base_i18n_samesource";
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

    with subtest("i18n-samesource: fn.sameSource unit contract + production wiring"):
        # ${evalAssertions} — renders only if same-source stays enforced
        # both in the pure helper and through the production module.
        machine.succeed("true")
  '';
}
