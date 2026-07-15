# @path: ~/projects/configs/nix-config/tests/nmt/default.nix
# @author: redskaber
# @datetime: 2026-05-12
# @description: tests::nmt::default — nmt-Plane runner + registry
#
# ── nmt bash-lib assertion API (assertions.sh) ────────────────────────
#
#   assertFileExists    "rel-path"           — [[ -f ]] check
#   assertPathNotExists "rel-path"           — [[ -e ]] absence check
#   assertFileContains  "rel-path" "needle"  — grep -qF "$needle" "$file"
#   assertFileRegex     "rel-path" "regex"   — grep -q  "$regex"  "$file"
#   assertFileContent   "rel-path" ref-file  — cmp/diff (2nd arg = FILE path)
#   assertLinkExists    "rel-path"           — [[ -L ]] symlink check
#
#   CRITICAL: assertFileContains uses:
#     grep -qF "$2" "$(_abs "$1")"
#   When $2 starts with "-" grep treats it as an option flag → error.
#   Use `regex` key for needles starting with "--" or "-".
#   assertFileRegex uses `grep -q "$2"` (unquoted 2nd arg in ERE mode).
#   Both functions pass $2 BEFORE the filename, so leading "-" breaks both.
#   Workaround: prefix needle with a space " --pager" won't work either.
#   Best workaround: use a needle that doesn't start with "-".
#
# ── pkgs.formats.* scrubbing ──────────────────────────────────────────
#
#   Modules writing config via pkgs.formats.toml/json/ini produce a
#   derivation as their config file.  With scrubbing that derivation
#   outPath → "@drv-name@" (a broken symlink target).
#   assertFileExists passes (symlink is present), but assertFileContains
#   fails because file content is absent.
#   Affected: programs.starship (formats.toml), programs.atuin (formats.toml),
#             programs.yazi settings/keymap (formats.toml).
#   Workaround: test only assertFileExists, OR use `extraConfig`/`initLua`
#   (plain text paths) for content assertions.
#
# ── fish + babelfish ──────────────────────────────────────────────────
#
#   HM fish module generates hm-session-vars.fish by running babelfish
#   to translate bash exports to fish syntax.  babelfish must be in the
#   whitelist as a REAL package.  If scrubbed, the builder fails with
#   "@babelfish@/bin/babelfish: No such file or directory".
#   The whitelist includes `babelfish` and `fish`.
#
# ── fzf + zsh integration ─────────────────────────────────────────────
#
#   programs.fzf.enableZshIntegration requires programs.zsh.enable = true.
#   HM injects fzf init into .zshrc via programs.zsh.initExtra.
#   FZF_DEFAULT_OPTS is written inline; option values (without leading "-")
#   are assertable via assertFileContains.
#
# ── fd ignore file ────────────────────────────────────────────────────
#
#   programs.fd.ignores → ~/.config/fd/ignore (one entry per line).
#   Plain text, fully assertable.
#
# ── ripgrep rcfile ────────────────────────────────────────────────────
#
#   programs.ripgrep.arguments → ~/.config/ripgrep/ripgreprc (one flag/line).
#   Plain text, assertable. Note: needles must NOT start with "-".
#   Use contains = [ "smart-case" ] not [ "--smart-case" ].
#
# ── jq config ─────────────────────────────────────────────────────────
#
#   programs.jq.colors → ~/.config/jq/jq (color definitions).
#   Plain text, assertable.
#
# ── yazi config ───────────────────────────────────────────────────────
#
#   programs.yazi.settings  → ~/.config/yazi/yazi.toml   (formats.toml → SCRUBBED)
#   programs.yazi.keymap    → ~/.config/yazi/keymap.toml  (formats.toml → SCRUBBED)
#   programs.yazi.initLua   → ~/.config/yazi/init.lua     (plain text → assertable)
#   Only existence check for TOML files; content assertions on init.lua only.

{ inputs
, shared
, ...
}:

let
  pkgs = shared.pkgs;
  lib  = pkgs.lib;

  nmtSrc    = inputs.nmt;
  hmPath    = inputs.home-manager;
  hmLib     = import "${hmPath}/modules/lib/stdlib-extended.nix" pkgs.lib;
  hmModules = import "${hmPath}/modules/modules.nix" {
    lib   = hmLib;
    pkgs  = pkgs;
    check = false;
  };

  # ── package scrubbing ─────────────────────────────────────────────────
  scrubDerivation = _name: value:
    let
      scrubbedValue = scrubDerivations value;
      newDrvAttrs   = {
        buildScript     = abort "no build allowed in nmt tests";
        outPath         = "@${lib.getName value}@";
        outputSpecified = true;
        __spliced       = { buildHost = value; hostTarget = value; };
      };
    in
      if lib.isAttrs value
      then (if lib.isDerivation value then scrubbedValue // newDrvAttrs else scrubbedValue)
      else value;

  scrubDerivations = lib.mapAttrs scrubDerivation;

  # Real packages kept for activation/assertion scripts.
  whitelist = _self: _super: {
    inherit (pkgs)
      coreutils diffutils findutils gnugrep gnused
      gettext glibcLocales
      babelfish fish          # fish: hm-session-vars.fish needs real babelfish
      delta nix-direnv;      # delta: wrapper binary; nix-direnv: source path
  };

  scrubbedPkgs =
    let raw = lib.makeExtensible (_: scrubDerivations pkgs);
    in raw.extend whitelist;

  # ── base module ───────────────────────────────────────────────────────
  baseModule = {
    _module.args.pkgs  = lib.mkForce scrubbedPkgs;
    xdg.enable             = lib.mkDefault true;
    home.username          = lib.mkDefault "testuser";
    home.homeDirectory     = lib.mkDefault "/home/testuser";
    home.stateVersion      = lib.mkDefault "${shared.version}";
    manual.manpages.enable = lib.mkDefault false;
  };

  # ── buildHomeManagerTest ──────────────────────────────────────────────
  # testSpec : { description ? ""; modules : [module]; tests : attrset }
  #
  # Per-test entry shape:
  #   { path     : string;
  #     exists   ? false;   → assertFileExists   (file must be present)
  #     absent   ? false;   → assertPathNotExists (path must be absent)
  #     contains ? [];      → assertFileContains  (fixed-string; NO "-" prefix!)
  #     regex    ? null;    → assertFileRegex     (ERE; NO "-" prefix!)
  #   }
  buildHomeManagerTest = testSpec:
    let
      mkScript = _name: t:
        let
          existsLine =
            if t ? exists && t.exists
            then ''assertFileExists "home-files/${t.path}"''
            else "";

          absentLine =
            if t ? absent && t.absent
            then ''assertPathNotExists "home-files/${t.path}"''
            else "";

          containsLines =
            if t ? contains
            then lib.concatMapStringsSep "\n"
              (needle: ''assertFileContains "home-files/${t.path}" ${lib.escapeShellArg needle}'')
              t.contains
            else "";

          regexLine =
            if t ? regex && t.regex != null
            then ''assertFileRegex "home-files/${t.path}" ${lib.escapeShellArg t.regex}''
            else "";
        in
          lib.concatStringsSep "\n"
            (lib.filter (s: s != "") [ existsLine absentLine containsLines regexLine ]);

      fullScript = lib.concatStringsSep "\n\n"
        (lib.mapAttrsToList mkScript testSpec.tests);

      nmtTestModule = {
        nmt.description = testSpec.description or "";
        nmt.script      = fullScript;
      };

      result = import nmtSrc {
        inherit pkgs;
        lib            = hmLib;
        modules        = hmModules ++ [ baseModule ] ++ (testSpec.modules or []);
        testedAttrPath = [ "home" "activationPackage" ];
        tests          = {
          ${testSpec.description or "test"} = nmtTestModule;
        };
      };
    in
      result.build.${testSpec.description or "test"};

  libWithNmt = lib.extend (_: _: {
    nmt.buildHomeManagerTest = buildHomeManagerTest;
  });

  buildTest = path: import path { lib = libWithNmt; };

in
{
  # ── core/exp/app/edito ───────────────────────────────────────────────
  nmt_home_core_exp_app_editor_nvim   = buildTest ./home/core/exp/app/editor/nvim.nix;

  # ── core/exp/sys/base ────────────────────────────────────────────────
  nmt_home_core_exp_sys_base_atuin    = buildTest ./home/core/exp/sys/base/atuin.nix;
  nmt_home_core_exp_sys_base_bat      = buildTest ./home/core/exp/sys/base/bat.nix;
  nmt_home_core_exp_sys_base_direnv   = buildTest ./home/core/exp/sys/base/direnv.nix;
  nmt_home_core_exp_sys_base_fd       = buildTest ./home/core/exp/sys/base/fd.nix;
  nmt_home_core_exp_sys_base_fzf      = buildTest ./home/core/exp/sys/base/fzf.nix;
  nmt_home_core_exp_sys_base_git      = buildTest ./home/core/exp/sys/base/git.nix;
  nmt_home_core_exp_sys_base_starship = buildTest ./home/core/exp/sys/base/starship.nix;
  nmt_home_core_exp_sys_base_tmux     = buildTest ./home/core/exp/sys/base/tmux.nix;
  nmt_home_core_exp_sys_base_yazi     = buildTest ./home/core/exp/sys/base/yazi.nix;
  nmt_home_core_exp_sys_base_zoxide   = buildTest ./home/core/exp/sys/base/zoxide.nix;

  # ── core/exp/sys/shell ───────────────────────────────────────────────
  nmt_home_core_exp_sys_shell_fish    = buildTest ./home/core/exp/sys/shell/fish.nix;
  nmt_home_core_exp_sys_shell_zsh     = buildTest ./home/core/exp/sys/shell/zsh.nix;

  # ── core/srv ─────────────────────────────────────────────────────────
  nmt_home_core_srv_security_gnupg    = buildTest ./home/core/srv/security/gnupg.nix;
  nmt_home_core_srv_notify_mako       = buildTest ./home/core/srv/notify/mako.nix;
}
