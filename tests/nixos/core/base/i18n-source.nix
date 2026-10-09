# @path: ~/projects/configs/nix-config/tests/nixos/core/base/i18n-source.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::nixos::core::base::i18n-source
# @source: nixos/core/base/i18n.nix
#
# T1.5 + T1.2 (regression guard, first production-tree import):
#
#   The fcitx5 "(not available)" incident (fix 995d8c9) happened because
#   i18n.inputMethod assembles its daemon from `pkgs` (stable) while
#   addons were taken from `shared.upkgs` (unstable). fcitx5 addon
#   metadata declares hard core-version dependencies (chinese-addons
#   5.1.14 requires core:5.1.22), so a mixed-source set silently
#   refuses to load every Chinese engine at runtime — an eval-time
#   healthy, run-time broken failure mode.
#
#   This check imports the REAL production module
#   (nixos/core/base/i18n.nix) and applies it to marker package sets:
#   stable and unstable packages stringify to distinct prefixes. The
#   assertion fails at eval time the moment addons stop coming from
#   the same source as the daemon scope (`with pkgs`).
#
# Marker semantics:
#   STABLE:fcitx5-chinese-addons  → correct (daemon scope: pkgs)
#   UNSTABLE:fcitx5-chinese-addons → regression (mixed source, 995d8c9)

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # REAL production fn.nix (phase-1 pure) — provides sameSource/pkgsFingerprint
  # for the T2.6 guard the production module now routes through.
  realFn = import ../../../../lib/shared/shared/fn.nix {
    inputs = { };
    enum = { };
    const = { };
    schema = { };
  };

  # Marker package sets — same attr names the production module consumes.
  # lib.trivial.version is the T2.6 fingerprint the guard compares.
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

  # Minimal shared contract consumed by the production module.
  mockShared = {
    upkgs = unstablePkgs; # the trap: any `with shared.upkgs` shows up as UNSTABLE:*
    pkgs = stablePkgs; # T2.6: the policy-declared (stable) scope
    i18nScope = stablePkgs; # T4.0: runtime-resolved declared scope
    fn = realFn; # T2.6: the sameSource guard itself
    time = {
      timeZone = "Asia/Shanghai";
      used-ip-timeZone = false;
    };
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocales = "zh_CN.UTF-8";
      extraLocalSetting = "zh_CN.UTF-8";
      nixpkgs-source = "stable"; # T2.6: declared source matches the daemon scope
    };
  };

  # ── REAL production import ────────────────────────────────────────
  production = import ../../../../nixos/core/base/i18n.nix {
    inputs = { };
    shared = mockShared;
    config = { };
    inherit lib;
    pkgs = stablePkgs; # daemon scope — addons MUST come from here too
  };

  addons = production.i18n.inputMethod.fcitx5.addons;
  fonts = production.fonts.packages;

  # ── Eval-time assertions ──────────────────────────────────────────
  evalAssertions =
    assert builtins.isList addons && addons != [ ];
    # the 995d8c9 regression: any addon pulled from shared.upkgs
    assert builtins.all (a: !lib.hasPrefix "UNSTABLE" (builtins.toString a)) addons;
    # addons must be the daemon-scope (stable) set
    assert builtins.any (a: lib.hasPrefix "STABLE:fcitx5-chinese-addons" (builtins.toString a)) addons;
    assert builtins.any (a: lib.hasPrefix "STABLE:fcitx5-rime" (builtins.toString a)) addons;
    # fonts share the same single source
    assert builtins.all (f: !lib.hasPrefix "UNSTABLE" (builtins.toString f)) fonts;
    # daemon type stays fcitx5 with the wayland frontend contract
    assert production.i18n.inputMethod.type == "fcitx5";
    assert production.i18n.inputMethod.fcitx5.waylandFrontend == true;
    "eval-assertions-passed";
in
{
  name = "nixos_core_base_i18n_source";
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

    with subtest("i18n-source: production module evaluated, addons/daemon single-sourced"):
        # ${evalAssertions} — if this line renders, the mixed-source
        # regression (995d8c9) cannot have re-entered the tree.
        machine.succeed("true")
  '';
}
