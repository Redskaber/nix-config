# @path: ~/projects/configs/nix-config/tests/nmt/default.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: tests::nmt::default — nmt-Plane registry
#
# ═══════════════════════════════════════════════════════════════════════
# nmt-Plane (Plane 5): Zero-VM HM dotfile assertions
# ═══════════════════════════════════════════════════════════════════════
#
# Speed:  <10 s per test (pure Nix eval, no QEMU)
# Focus:  Generated dotfile content — existence + key-value correctness
# Naming: nmt_<module-path-underscored>
#
# ── nmt acquisition ───────────────────────────────────────────────────
#
#   inputs.nmt  →  github:Redskaber/nmt  (flake = false)
#
# Sourcehut (git.sr.ht) blocks ALL Nix fetcher user-agents with HTTP 403
# via the go-away bot-protection system.  The github.com/Redskaber/nmt
# mirror is the only reachable copy.  Because the repo has no flake.nix,
# we declare it with `flake = false` in flake.nix; `inputs.nmt` is then
# simply the store path of the checked-out source tree.
#
# ── nmt true API (default.nix signature) ──────────────────────────────
#
#   import nmtSrc { inherit pkgs lib modules testedAttrPath tests; }
#   → { build; run; report; list }
#
# `buildHomeManagerTest` does NOT exist in nmt itself — it is a wrapper
# invented by home-manager's own tests/default.nix.  We re-implement it
# here using home-manager's module system from inputs.home-manager.
#
# ── buildHomeManagerTest contract ─────────────────────────────────────
#
#   buildHomeManagerTest { description, modules, tests } pkgs
#
# Each test file under tests/nmt/home/**/*.nix calls:
#
#   lib.nmt.buildHomeManagerTest {
#     description = "…";
#     modules     = [{ home.username = "testuser"; … }];
#     tests       = {
#       "foo: file exists"      = { path = "…"; exists   = true; };
#       "foo: value written"    = { path = "…"; contains = [ "…" ]; };
#     };
#   }
#
# ── scrubbing ──────────────────────────────────────────────────────────
#
# All derivations are replaced with "@pkg-name@" placeholders so that
# tests evaluate entirely without building packages.  A small whitelist
# of packages needed by activation scripts is kept unscrubbed.
#
# ── adding a new test ─────────────────────────────────────────────────
#   1. Create  tests/nmt/home/<path>/<name>.nix
#   2. Register: nmt_home_<path>_<name> = buildTest ./home/<path>/<name>.nix;
#   3. tests/default.nix auto-merges — no edit needed.
#
# ═══════════════════════════════════════════════════════════════════════

{ inputs
, shared
, ...
}:

let
  pkgs = shared.pkgs;
  lib  = pkgs.lib;

  # ── nmt source ────────────────────────────────────────────────────────
  # inputs.nmt is the raw store path of github:Redskaber/nmt (flake=false).
  nmtSrc = inputs.nmt;

  # ── home-manager lib + modules ────────────────────────────────────────
  # We use home-manager's own stdlib-extended lib (which includes hm helpers)
  # and its module list to evaluate test configurations exactly as HM would.
  hmPath   = inputs.home-manager;
  hmLib    = import "${hmPath}/modules/lib/stdlib-extended.nix" pkgs.lib;
  hmModules = import "${hmPath}/modules/modules.nix" {
    lib   = hmLib;
    pkgs  = pkgs;
    check = false;
  };

  # ── package scrubbing ─────────────────────────────────────────────────
  # Replace every derivation outPath with "@pkg-name@" so tests never
  # trigger a real build.  Mirror of home-manager tests/default.nix logic.
  scrubDerivation = name: value:
    let scrubbedValue = scrubDerivations value;
        newDrvAttrs = {
          buildScript   = abort "no build allowed in nmt tests";
          outPath       = "@${lib.getName value}@";
          outputSpecified = true;
          __spliced = { buildHost = value; hostTarget = value; };
        };
    in if lib.isAttrs value
       then (if lib.isDerivation value
             then scrubbedValue // newDrvAttrs
             else scrubbedValue)
       else value;

  scrubDerivations = lib.mapAttrs scrubDerivation;

  # Packages that activation scripts actually execute — keep them real.
  whitelist = _self: _super: {
    inherit (pkgs)
      coreutils diffutils findutils gnugrep gnused
      gettext glibcLocales
      babelfish fish;   # needed by shell init tests
  };

  scrubbedPkgs =
    let raw = lib.makeExtensible (_: scrubDerivations pkgs);
    in raw.extend whitelist;

  # ── base HM module injected into every test ────────────────────────────
  # Mirrors the base module in home-manager/tests/default.nix:
  #   - override pkgs with scrubbed instance
  #   - fix home.username / homeDirectory so tests are deterministic
  #   - disable manpages (avoids unnecessary rebuilds)
  baseModule = {
    _module.args.pkgs = lib.mkForce scrubbedPkgs;

    xdg.enable                  = lib.mkDefault true;
    home.username               = lib.mkDefault "testuser";
    home.homeDirectory          = lib.mkDefault "/home/testuser";
    home.stateVersion           = lib.mkDefault "25.11";
    manual.manpages.enable      = lib.mkDefault false;
  };

  # ── buildHomeManagerTest ──────────────────────────────────────────────
  # Wraps nmt's raw { modules, testedAttrPath, tests } API with the
  # home-manager–aware scaffolding.
  #
  # testSpec  : { description ? ""; modules : [module]; tests : attrset }
  # Returns   : derivation (nmt build result for this test)
  buildHomeManagerTest = testSpec:
    let
      # Convert our declarative `tests` attrset into nmt script lines.
      # Each entry supports:
      #   { path; exists ? false; contains ? []; }
      mkScript = name: t:
        let
          # assertFileExists / assertFileContent come from nmt bash-lib
          existsCheck =
            if t ? exists && t.exists then
              ''assertFileExists "home-files/${t.path}"''
            else "";
          containsChecks =
            if t ? contains then
              lib.concatMapStringsSep "\n" (needle:
                ''assertFileContent "home-files/${t.path}" "${needle}"''
              ) t.contains
            else "";
        in lib.concatStringsSep "\n" (lib.filter (s: s != "") [existsCheck containsChecks]);

      # Combine all per-assertion scripts into one nmt.script block.
      fullScript = lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList mkScript testSpec.tests
      );

      # The single nmt test module for this test case.
      nmtTestModule = {
        nmt.description = testSpec.description or "";
        nmt.script      = fullScript;
      };

      # All modules: HM infrastructure + base fix-ups + user config + nmt assertions.
      allModules = hmModules ++ [ baseModule ] ++ (testSpec.modules or []) ++ [ nmtTestModule ];

      # nmt testedAttrPath: home-manager's activation package.
      testedAttrPath = [ "home" "activationPackage" ];

      # Single-test attrset for nmt.
      nmtTests = {
        ${testSpec.description or "test"} = nmtTestModule;
      };

      # Invoke nmt.
      result = import nmtSrc {
        inherit pkgs testedAttrPath;
        lib     = hmLib;
        modules = hmModules ++ [ baseModule ] ++ (testSpec.modules or []);
        tests   = {
          ${testSpec.description or "test"} = nmtTestModule;
        };
      };
    in
      # Return the build derivation for this test (what flake checks expect).
      result.build.${testSpec.description or "test"};

  # ── lib with nmt shim ─────────────────────────────────────────────────
  # Expose buildHomeManagerTest on lib.nmt so test files can call
  #   lib.nmt.buildHomeManagerTest { ... }
  # without knowing the implementation details.
  libWithNmt = lib.extend (_: _: {
    nmt.buildHomeManagerTest = buildHomeManagerTest;
  });

  # ── Runner: buildTest ─────────────────────────────────────────────────
  buildTest = path:
    let expr = import path { lib = libWithNmt; };
    in expr;   # expr IS already the derivation returned by buildHomeManagerTest

in

# ══════════════════════════════════════════════════════════════════════
# nmt-Plane registry
# Naming: nmt_home_<module-path-with-underscores>
# ══════════════════════════════════════════════════════════════════════
{
  # ── core/base tooling ─────────────────────────────────────────────
  nmt_home_core_base_git          = buildTest ./home/core/base/git.nix;
  nmt_home_core_base_starship     = buildTest ./home/core/base/starship.nix;
  nmt_home_core_base_direnv       = buildTest ./home/core/base/direnv.nix;
  nmt_home_core_base_atuin        = buildTest ./home/core/base/atuin.nix;
  nmt_home_core_base_zoxide       = buildTest ./home/core/base/zoxide.nix;
  nmt_home_core_base_tmux         = buildTest ./home/core/base/tmux.nix;
  nmt_home_core_base_bat          = buildTest ./home/core/base/bat.nix;

  # ── core/exp/sys/shell ────────────────────────────────────────────
  nmt_home_core_exp_sys_shell_zsh  = buildTest ./home/core/exp/sys/shell/zsh.nix;
  nmt_home_core_exp_sys_shell_fish = buildTest ./home/core/exp/sys/shell/fish.nix;

  # ── core/exp/app ──────────────────────────────────────────────────
  nmt_home_core_exp_app_nvim       = buildTest ./home/core/exp/app/nvim.nix;

  # ── core/srv ──────────────────────────────────────────────────────
  nmt_home_core_srv_gnupg          = buildTest ./home/core/srv/gnupg.nix;
  nmt_home_core_srv_mako           = buildTest ./home/core/srv/mako.nix;
}
