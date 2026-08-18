# @path: ~/projects/configs/nix-config/lib/shared/runtime/default.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::runtime::default — Phase 2 runtime injection
#
# Phase 2 of the two-phase shared initialisation.
# Merges schema+enum+tools (phase 1) with user_shared (shared.nix values) and
# injects runtime-only fields that require pkgs or inputs.
#
# Merge order: shared (schema+enum+tools) <- user_shared <- runtime fields
# Later keys win; runtime fields always override any same-named user_shared key.

{ shared
, user_shared
, nixpkgs
, nixpkgs-unstable
, inputs
, ...
}:
let
  isNixOS     = shared.fn.isNixOS user_shared.platform;
  sopsFile    = shared.fn.sopsFile shared.self shared.const.secrets.chipr;
  sopsPath    = shared.fn.sopsRuntimePath shared.const.secrets.runtimePath;
  sopsUserPath= shared.fn.sopsRuntimePath shared.const.secrets.forUsersPath;
  homeDir     = shared.fn.homeDir user_shared.platform user_shared.user.username;
  pattrs      = if user_shared ? nixpkgs
                then { system = user_shared.arch.tag; } // user_shared.nixpkgs
                else { system = user_shared.arch.tag; };
  pkgs        = import nixpkgs pattrs;
  upkgs       = import nixpkgs-unstable pattrs;

  # External tool libraries — resolved at runtime (arch-specific where needed)
  # Config files access via shared.tools.<name> (short, decoupled from inputs)
  orc-lib     = shared.tools.orc-raw.${user_shared.arch.tag};
  pdshell-lib = shared.tools.pdshell-raw;

  core_shared = shared // user_shared // {
    inherit
      homeDir
      pkgs upkgs
      isNixOS
      sopsFile sopsPath sopsUserPath
    ;
    _user_shared = user_shared;

    # External tools (resolved at runtime, short paths for config files)
    orc = orc-lib;
    pdshell = pdshell-lib;
    inherit (pdshell-lib) mk-pdshell pdshells;
    # tools attrset is already in shared (from phase 1), but we override
    # with resolved arch-specific orc so config files can use shared.tools.orc
    tools = shared.tools // {
      orc = orc-lib;  # resolved per-arch
    };

    # shellIntegrations: computed from shared.user.shell.tag
    # Config: programs.fzf = shared.shellIntegrations // { enable = true; ... };
    shellIntegrations = let tag = user_shared.user.shell.tag; in {
      enableZshIntegration = tag == "zsh";
      enableFishIntegration = tag == "fish";
      enableBashIntegration = tag == "bash";
    };

    # Application sets (multi-select routing): expanded from user_shared set variants
    # Config: imports = builtins.map (e: ./${e}.nix) shared.editors;
    editors   = user_shared.editor-set.value.editors;
    terminals = user_shared.terminal-set.value.terminals;
    browsers  = user_shared.browser-set.value.browsers;

    # Service profile (strategy carrying): expanded from user_shared variant
    # Config: enable = shared.services.db.postgresql.install;
    #         wantedBy = lib.mkForce (lib.optional shared.services.db.postgresql.autostart "multi-user.target");
    services = user_shared.service-profile.value;
  };

  runtime_shared = core_shared // {
    packages = import "${core_shared.self}/pkgs" { inherit pkgs; };
    overlays = import "${core_shared.self}/overlays" { shared = core_shared; };
  };
in runtime_shared
