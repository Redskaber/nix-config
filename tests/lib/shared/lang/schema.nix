# @path: ~/projects/configs/nix-config/tests/lib/shared/lang/schema.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::lib::shared::lang::schema
# @source: lib/shared/lang/schema.nix
#
# Asserts run against the REAL production
# schema.nix destructuring validators. Lambda-pattern schemas fail at
# eval time when required keys are missing — this test proves the
# contract on real code BOTH ways:
#
#   - positive: well-formed input passes every validator (identity)
#   - negative (STATIC): every mandatory key is declared WITHOUT a
#     default in the real pattern, via builtins.functionArgs.
#   - composition: schema.shared APPLIES the nested i18n
#     validator — its defaults fire for real (identity for i18n does
#     NOT hold; the default is materialised into the result).
#
# The negative direction is asserted statically because Nix ≥2.35 lets
# missing-argument errors ESCAPE builtins.tryEval — a dynamic
# "remove a key and expect rejection" harness would silently turn
# uncatchable on this Nix.
#
# Covered (real code paths):
#   - schema.user / git / rbw / time / i18n identity on valid inputs
#   - schema.shared requires all 18 mandatory keys (functionArgs)
#   - sub-schemas declare their mandatory keys (functionArgs)
#   - optional keys with defaults (nixpkgs.overlays / config,
#     i18n.nixpkgs-source — the dual-source declaration)

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # ── REAL production import ────────────────────────────────────────
  realSchema = import ../../../../lib/shared/lang/schema.nix;

  validShared = {
    arch = "x86_64-linux";
    drive = {
      tag = "intel";
      value = [ "intel" ];
    };
    platform = "nixos";
    window-manager = "hyprland";
    display-manager = "ly";
    # The sound axis answers the schema like its dm/wm siblings —
    # mandatory, so every policy chain declares it.
    sound = "pipewire";
    pointer-cursor = "bibata";
    version = "v26_05";
    editor = "nvim";
    devDir = "/dev";
    hostName = "nixos";
    user = {
      username = "kilig";
      shell = {
        tag = "zsh";
      };
      openssh-authKeys = [ ];
    };
    git = {
      defaultBranch = "main";
      name = "redskaber";
      email = "redskaber@foxmail.com";
      lazygit = { };
    };
    rbw = {
      email = "a@b.c";
      lock_timeout = 3600;
    };
    time = {
      used-ip-timeZone = false;
      timeZone = "Asia/Shanghai";
    };
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocalSetting = "zh_CN.UTF-8";
      extraLocales = "zh_CN.UTF-8";
    };
    secrets = {
      sshKeyPaths = [ ];
      nixos = { };
    };
    nixpkgs = { };
  };

  # ── Static mandatory-key contract ──────────────────────────────────
  # functionArgs reports every pattern attr with `false` when it has
  # NO default (= mandatory). Asserting on the real pattern is both
  # stronger and Nix-2.35-safe: the removal-rejection behaviour of a
  # destructuring validator follows from exactly this declaration.
  sharedArgs = builtins.functionArgs realSchema.shared;

  mandatoryKeys = [
    "arch"
    "drive"
    "platform"
    "window-manager"
    "display-manager"
    "sound"
    "pointer-cursor"
    "version"
    "editor"
    "devDir"
    "hostName"
    "user"
    "git"
    "rbw"
    "time"
    "i18n"
    "secrets"
    "nixpkgs"
  ];

  # ── Eval-time assertions ───────────────────────────────────────────
  evalAssertions =
    assert realSchema.user validShared.user == validShared.user;
    assert realSchema.git validShared.git == validShared.git;
    assert realSchema.rbw validShared.rbw == validShared.rbw;
    assert realSchema.time validShared.time == validShared.time;
    # The i18n validator MATERIALISES its default — the `@`
    # capture alone returns the caller's attrset untouched, so the
    # declared `nixpkgs-source ? "stable"` reaches the composed
    # result (plain identity would hold for the wrong reason).
    assert realSchema.i18n validShared.i18n == validShared.i18n // { nixpkgs-source = "stable"; };
    assert
      (realSchema.i18n (validShared.i18n // { nixpkgs-source = "unstable"; })).nixpkgs-source
      == "unstable";
    # Composed result — top level passes through untouched, the
    # nested i18n validator materialises its default (SSOT: defaults
    # live in the schema, not in per-leaf `or` fallbacks).
    assert (realSchema.shared validShared).i18n.nixpkgs-source == "stable";
    assert (realSchema.shared validShared).i18n == validShared.i18n // { nixpkgs-source = "stable"; };
    assert
      builtins.removeAttrs (realSchema.shared validShared) [ "i18n" ]
      == builtins.removeAttrs validShared [ "i18n" ];
    # every documented mandatory key is declared required in the REAL pattern
    assert builtins.all (key: builtins.hasAttr key sharedArgs && !sharedArgs.${key}) mandatoryKeys;
    # sub-schemas declare their own mandatory keys
    assert (builtins.functionArgs realSchema.user).username == false;
    assert (builtins.functionArgs realSchema.git).email == false;
    # optional keys with defaults survive on the real pattern
    assert (builtins.functionArgs realSchema.i18n).nixpkgs-source == true; # dual-source declaration
    assert (builtins.functionArgs realSchema.nixpkgs).overlays == true;
    "eval-assertions-passed";
in
{
  name = "lib_shared_lang_schema";
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

    with subtest("schema: production sources evaluated with all assertions"):
        # Real schema.nix validators were exercised both ways at eval
        # time (${evalAssertions}); the VM only proves the check boots.
        machine.succeed("true")
  '';
}
