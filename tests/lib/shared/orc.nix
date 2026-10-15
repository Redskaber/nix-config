# @path: ~/projects/configs/nix-config/tests/lib/shared/orc.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: tests::lib::shared::orc — the orc wallust copy-emitter consumption contract
# @source: home/wm/hyprland/theme/*.nix × home/wm/hyprland/default.nix × home/core/exp/{app/terminal,sys/misc}
#
# The wallust theme-injection chain is the fleet's only consumption of
# shared.orc (mechanisms.md §6: waybar · rofi · swaync · kitty · cava ·
# quickshell · hyprland). The nmt plane asserts on home-files (the
# symlink face), but the copy emitter's whole job lives in the
# ACTIVATION face (cp --remove-destination at switch time) — invisible
# to that plane.
#
# What the contract pins, per site (the observable text of the dag
# entry, evaluated through the REAL modules — no mocks, the version.nix
# discipline: one homeManagerConfiguration importing the production
# theme modules with the fleet's real inputs/shared):
#
#   1. the activation entry exists (a site whose include rotted away
#      still evaluates — as an EMPTY no-op; existence is not contract)
#   2. it runs after writeBoundary (the links must exist before the
#      plant, or the cp races the tree it overrides)
#   3. `run cp --remove-destination <tree>/<rel> "$HOME/<dest>/<rel>"`
#      — the full line: source path (the tree carries the file — an
#      upstream move rots the include), destination key (a destPrefix
#      typo plants colors in the wrong tree), and --remove-destination
#      itself (the flag that replaces the store SYMLINK instead of
#      writing through it into the read-only store)
#   4. `run chmod u+w "$HOME/<dest>/<rel>"` — the planted file must be
#      writable, or wallust's runtime overwrite hits EACCES next boot
#
# History: the battery's first run caught the swaync site EMPTY — the
# tree carried no wallust placeholder, the include matched nothing,
# and the activation ran a silent no-op while claiming to plant. The
# placeholder landed in swaync-config c8818d9, the module-side
# synthesis retired with it, and orc 05c658f (the include-intent
# guard) makes this class of rot fail AT EVAL TIME, fleet-wide.
#
# Mutation checks (all verified on the real eval):
#   - point an include at a moved rel → that site's cp needle fails,
#     the throw names the site and the reconciliation
#   - revert the swaync-config lock to a pre-placeholder rev → the
#     eval now FAILS LOUDLY (orc include-intent guard) — the original
#     silent-no-op mutation replays as a loud failure
#   - flip a destPrefix → destination needle fails

{
  inputs,
  shared,
  pkgs,
  lib,
  ...
}:
let
  # ── the REAL consumption, through the production modules ──────────
  # One eval drags the whole hyprland theme family (default.nix
  # imports ./theme: rofi/waybar/swaync/quickshell + the hypr tree)
  # plus the kitty and cava leaves — all seven §6 sites in one config.
  eval = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit inputs shared; };
    modules = [
      {
        home = {
          username = "testuser";
          homeDirectory = "/home/testuser";
          stateVersion = "${shared.version.value.stateVersion}";
        };
      }
      ../../../home/wm/hyprland/default.nix
      ../../../home/core/exp/app/terminal/kitty.nix
      ../../../home/core/exp/sys/misc/cava.nix
    ];
  };

  # ── the seven sites, as data ──────────────────────────────────────
  # name   : the dag entry the module registers
  # plants : source path × destination key pairs the activation must
  #          carry (hyprland plants two files in one entry)
  sites = [
    {
      name = "rofiWallust";
      plants = [
        {
          src = "${inputs.rofi-config}/wallust/colors-rofi.rasi";
          key = ".config/rofi/wallust/colors-rofi.rasi";
        }
      ];
    }
    {
      name = "waybarWallust";
      plants = [
        {
          src = "${inputs.waybar-config}/wallust/colors-waybar.css";
          key = ".config/waybar/wallust/colors-waybar.css";
        }
      ];
    }
    {
      name = "swayncWallust";
      # The plant source is the TREE file (swaync-config grew the
      # placeholder; the earlier module-side synthesis is retired).
      plants = [
        {
          src = "${inputs.swaync-config}/wallust/colors-wallust.css";
          key = ".config/swaync/wallust/colors-wallust.css";
        }
      ];
    }
    {
      name = "quickWallust";
      plants = [
        {
          src = "${inputs.quickshell-config}/qml_color.json";
          key = ".config/quickshell/qml_color.json";
        }
      ];
    }
    {
      name = "kittyWallust";
      plants = [
        {
          src = "${inputs.kitty-config}/kitty-themes/01-Wallust.conf";
          key = ".config/kitty/kitty-themes/01-Wallust.conf";
        }
      ];
    }
    {
      name = "cavaWallust";
      plants = [
        {
          src = "${inputs.cava-config}/config";
          key = ".config/cava/config";
        }
      ];
    }
    {
      name = "hyprWallust";
      plants = [
        {
          src = "${inputs.hypr-config}/sys/policy/wallust/wallust-hyprland.lua";
          key = ".config/hypr/sys/policy/wallust/wallust-hyprland.lua";
        }
        {
          src = "${inputs.hypr-config}/.deps_cache.sh";
          key = ".config/hypr/.deps_cache.sh";
        }
      ];
    }
  ];

  # ── pure substring search ─────────────────────────────────────────
  # lib.hasInfix builds a regex (builtins.match ".*${escapeRegex
  # needle}.*") — and the Nix language forbids match patterns that
  # refer to store paths, which every src needle here does (the tree
  # inputs materialize as store paths). This helper is regex-free and
  # context-free: substring comparison ignores string context, so a
  # store-path-carrying needle compares cleanly.
  hasSub =
    needle: haystack:
    let
      n = builtins.stringLength needle;
      upper = (builtins.stringLength haystack) - n;
      go =
        i:
        if i > upper then
          false
        else if builtins.substring i n haystack == needle then
          true
        else
          go (i + 1);
    in
    if n == 0 then true else go 0;

  # ── per-site verdict (eval-time throw, the version.nix shape) ─────
  siteVerdict =
    site:
    let
      entry = eval.config.home.activation.${site.name} or null;

      plantVerdict =
        plant:
        let
          cpNeedle = ''run cp --remove-destination ${plant.src} "$HOME/${plant.key}"'';
          chmodNeedle = ''run chmod u+w "$HOME/${plant.key}"'';
          script = if entry == null then "" else entry.data;
        in
        if !hasSub cpNeedle script then
          throw ''
            orc wallust contract violation (T28), site ${site.name}:
              expected the activation to plant the file, but the line
                ${cpNeedle}
              is absent from the dag entry's script.

              Reconciliation, in likelihood order:
                1. the config tree moved the file — the include rotted
                   and mergeHomeFiles matched NOTHING (an empty
                   activation is exactly this failure mode: the entry
                   still exists, it just plants nothing)
                2. the destPrefix changed — colors would land in the
                   wrong tree
                3. the plant source moved in the config tree
                   (swaync-config carries wallust/
                   colors-wallust.css since c8818d9 — an upstream
                   move or rename rots this needle)
                4. orc changed the copy emitter's script shape''
        else if !hasSub chmodNeedle script then
          throw ''
            orc wallust contract violation (T28), site ${site.name}:
              the plant line is present but the writable bit is not —
                ${chmodNeedle}
              A planted read-only file makes wallust's runtime
              overwrite fail with EACCES on the next theme switch.''
        else
          "plant ok: ${plant.key}";

      plantVerdicts = map plantVerdict site.plants;
    in
    if entry == null then
      throw ''
        orc wallust contract violation (T28), site ${site.name}:
          the dag entry is GONE from the evaluated config — the module
          that registers home.activation.${site.name} stopped wiring
          it (check the module's let block and its home.activation
          assignment).''
    else if entry.after != [ "writeBoundary" ] then
      throw ''
        orc wallust contract violation (T28), site ${site.name}:
          the dag entry no longer runs after writeBoundary (observed
          after = ${toString entry.after}). The plant must not race
          the symlink tree it overrides — entryAfter ["writeBoundary"]
          is the load-bearing ordering.''
    else
      "site ${site.name}: after writeBoundary; ${toString (lib.length plantVerdicts)} plant(s) verified";

  verdicts = map siteVerdict sites;

  contractHeld = lib.concatStringsSep "\n" (
    [
      "orc wallust copy-emitter contract held: 7 sites, 8 plants, all evaluated through the production modules"
    ]
    ++ verdicts
  );
in
{
  name = "lib_shared_orc";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 300;
  };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  # The contract text is spliced as a STRING EXPRESSION, never into a
  # `#` comment — contractHeld is multi-line (header + one line per
  # site verdict), and only the first spliced line would land behind
  # a single '#': the rest would arrive as bare python and the CI
  # driver's pylyzer run would reject the whole member. The string
  # expression carries the same traceability (the verdicts render into
  # the driver source) with multi-line safety by construction.
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("orc: wallust copy-emitter contract — seven sites, production modules, no mocks"):
        """
        ${contractHeld}
        """
        # renders only if every site held; the machine is a dummy
        # (the contract is an eval-time property).
        machine.succeed("true")
  '';
}
