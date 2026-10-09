# @path: ~/projects/configs/nix-config/tests/home/core/base/i18n-source.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::home::core::base::i18n-source
# @source: home/core/base/i18n.nix
#
# T1.2 (production-tree import, HM side of the 995d8c9 incident):
#
#   The standalone-HM twin of nixos/core/base/i18n.nix: on non-NixOS
#   platforms the fcitx5 daemon is assembled by Home Manager's own pkgs
#   (stable), so the addons below MUST come from the same scope. This
#   check imports the REAL production module and applies it to marker
#   package sets — the same marker semantics as i18n-source.nix on the
#   NixOS plane:
#
#     STABLE:fcitx5-chinese-addons  → correct (daemon scope: pkgs)
#     UNSTABLE:fcitx5-chinese-addons → regression (mixed source, 995d8c9)
#
#   Mutating the production module (e.g. flipping `with pkgs` back to
#   `with shared.upkgs`) turns this check red at eval time — no VM boot
#   required for the regression signal.

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

  # Marker package set — same attr names the production module consumes.
  # lib.trivial.version is the T2.6 fingerprint the guard compares.
  markPkgs = prefix: fpVersion: {
    lib.trivial.version = fpVersion;
    fcitx5-rime = "${prefix}:fcitx5-rime";
    fcitx5-gtk = "${prefix}:fcitx5-gtk";
    fcitx5-nord = "${prefix}:fcitx5-nord";
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
    # standalone HM platform: the module self-enables from resolved
    # capability facts (T4.0) — linux-family, no nixos system layer.
    caps = {
      linux-family = true;
      nixos-system = false;
    };
    upkgs = unstablePkgs; # the trap: any `with shared.upkgs` shows up as UNSTABLE:*
    pkgs = stablePkgs; # T2.6: the policy-declared (stable) scope
    i18nScope = stablePkgs; # T4.0: runtime-resolved declared scope
    fn = realFn; # T2.6: the sameSource guard itself
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocalSetting = "zh_CN.UTF-8";
      nixpkgs-source = "stable"; # T2.6: declared source matches the daemon scope
    };
  };

  # ── REAL production import ────────────────────────────────────────
  production = import ../../../../home/core/base/i18n.nix {
    inherit inputs lib;
    shared = mockShared;
    config = { };
    pkgs = stablePkgs; # daemon scope — addons MUST come from here too
  };

  im = production.i18n.inputMethod;
  addons = im.fcitx5.addons;

  # ── Eval-time assertions ──────────────────────────────────────────
  evalAssertions =
    # standalone HM: module self-enables away from NixOS
    assert im.enable == true;
    assert im.type == "fcitx5";
    assert im.fcitx5.waylandFrontend == true;
    assert im.fcitx5.ignoreUserConfig == false;
    assert builtins.isList addons && builtins.length addons == 6;
    # the 995d8c9 regression: any addon pulled from shared.upkgs
    assert builtins.all (a: !lib.hasPrefix "UNSTABLE" (builtins.toString a)) addons;
    # addons must be the daemon-scope (stable) set
    assert builtins.any (a: lib.hasPrefix "STABLE:fcitx5-chinese-addons" (builtins.toString a)) addons;
    assert builtins.any (a: lib.hasPrefix "STABLE:fcitx5-rime" (builtins.toString a)) addons;
    # locale propagation into session variables
    assert production.home.sessionVariables.LANG == "en_US.UTF-8";
    assert production.home.sessionVariables.LC_TIME == "zh_CN.UTF-8";
    # user config wiring uses the REAL flake input
    assert production.xdg.configFile."fcitx5".source == inputs.fcitx5-config;
    "eval-assertions-passed";
in
{
  name = "home_core_base_i18n_source";
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

    with subtest("i18n-source(HM): production module evaluated, addons/daemon single-sourced"):
        # ${evalAssertions} — if this line renders, the mixed-source
        # regression (995d8c9) cannot have re-entered the HM tree.
        machine.succeed("true")
  '';
}
