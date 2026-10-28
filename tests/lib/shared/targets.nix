# @path: ~/projects/configs/nix-config/tests/lib/shared/targets.nix
# @author: redskaber
# @datetime: 2026-10-28
# @description: tests::lib::shared::targets — the fact-source + naming census
# @source: lib/shared/targets.nix (host classification + output naming) × hosts/ (machine facts)
#
# Every host's hardware facts must be declared in EXACTLY the shape its
# platform can consume — locked here as a census over the hosts/ tree,
# evaluated through the classifier's own lenses:
#
#   Law A (never both)        — no host may carry hardware.nix AND
#       facter.json. The two shapes declare the same facts twice; drift
#       between them is silent. This is also the migration's own failure
#       mode — `just hardware-migrate` flips the wiring and retires the
#       legacy file in ONE command precisely so this state never
#       persists (the census fires on file presence, imported or not).
#   Law B (bare-metal NixOS)  — a nixos-system host WITHOUT the wsl bit
#       carries EXACTLY ONE source (either shape; never zero).
#   Law C (hosted elsewhere) — wsl-class NixOS, darwin and standalone
#       hosts carry ZERO: the Windows host owns a WSL machine's
#       hardware, nix-darwin keeps its own facts, a standalone HM
#       closure has no system to consume them — a source file nobody
#       consumes is dead data (a lying file).
#   Law G (no shadowed names) — the output namespaces are keyed by the
#       hosts/ directory name (per-kind unique, a symbol table); the
#       ONE synthetic name the pipeline mints — the legacy alias
#       <user>-<platform> — may never shadow a real host directory
#       (the guard in targets.nix makes it an eval throw), no face
#       name may carry an arch tag (arch is a pkgs-synthesis VALUE,
#       never an address), and hostName answers its directory on
#       every host (the loader's force-alignment contract).
#
# Construction discipline (the wsl.nix precedent): each host's policy is
# built exactly like targets.nix mkShared — same loader, same args, same
# hostName — so the census reads the SAME caps the classifier reads;
# hosts/ is enumerated the same way the inventory frontend enumerates
# it. The naming census extends the discipline to the OUTPUT faces:
# they are read through the real target factory (the same module
# faces.nix consumes, same args), attrNames only — closure thunks stay
# unforced (drvPath equivalence is CI's job, not the census's). File
# presence IS the declaration (the data-and-interpreter split taken to
# its conclusion): a fact source that exists but is not wired is still
# counted — that is the point.
#
# Mutation check: delete hosts/nixos/hardware.nix without flipping the
# wiring → Law B fires with the host named; park a stray hardware.nix in
# hosts/darwin → Law C fires; leave both files mid-migration → Law A
# fires with both named; mkdir hosts/kilig-nixos (colliding with the
# legacy alias) → Law G fires, both here and at any nixosConfigurations
# evaluation (the targets.nix guard).

{
  inputs,
  shared,
  pkgs,
  lib,
  ...
}:
let
  # ── the REAL host policies, the classifier's own construction ──────
  # (lazy attrs: forcing only .caps keeps the unforced channels free)
  hostShared =
    h:
    import ../../../lib/shared {
      inherit (inputs) self nixpkgs nixpkgs-unstable;
      inherit inputs;
      hostName = h;
    };

  # ── the hosts/ frontend, the inventory's own enumeration ───────────
  hostsDir = ../../../hosts;
  hostNames = builtins.attrNames (
    lib.filterAttrs (_: t: t == "directory") (builtins.readDir hostsDir)
  );

  factSources = [
    "hardware.nix"
    "facter.json"
  ];
  present = h: builtins.filter (f: builtins.pathExists (hostsDir + "/${h}/${f}")) factSources;

  # ── the census: one verdict line per host ───────────────────────────
  verdicts = map (
    h:
    let
      caps = (hostShared h).caps;
      srcs = present h;
      count = builtins.length srcs;
      # the platform's own answer to "where do this machine's
      # hardware facts live": on the machine (bare NixOS), or with
      # whoever owns the environment it runs in (wsl/darwin/
      # standalone).
      bareMetal = caps.nixos-system && !caps.wsl;
      lawful = (count <= 1) && (if bareMetal then count == 1 else count == 0);
    in
    {
      inherit h lawful;
      line =
        if lawful then
          "  ${h}: lawful (${toString count} source${if count == 1 then "" else "s"}, ${
              if bareMetal then "bare-metal" else "hosted-elsewhere"
            })"
        else
          "  ${h}: VIOLATION — carries [${lib.concatStringsSep ", " srcs}]"
          + " but the platform demands ${
             if bareMetal then "exactly one source" else "zero (facts owned elsewhere)"
           }";
    }
  ) hostNames;

  violations = map (v: v.line) (lib.filter (v: !v.lawful) verdicts);

  censusVerdict =
    if violations == [ ] then
      "all ${toString (builtins.length hostNames)} hosts lawful — Law A (no doubles) held, Law B (bare metal carries exactly one) held, Law C (hosted-elsewhere carries zero) held"
    else
      throw ''
        fact-source census violations (T19.1):
        ${lib.concatStringsSep "\n" violations}

        Each host's hardware facts live in hosts/<h>/ in exactly one shape:
        bare-metal NixOS hosts carry ONE of hardware.nix (legacy) or
        facter.json (declarative) — never both, never neither; hosts whose
        environment owns their hardware (wsl-class, darwin, standalone HM)
        carry ZERO. Migrate with `just hardware-migrate` (run ON the
        machine); see tests/lib/shared/targets.nix's header for the laws.'';

  # ── Law G: the naming census over the output namespaces ──────
  # The faces are read through the REAL target factory — the same
  # module faces.nix consumes, same args — attrNames only: the
  # closure thunks stay unforced. Forcing the names is exactly deep
  # enough to fire the Law G guard in targets.nix (the `//` merge
  # forces attrNames of the shadow check before the alias can win).
  targets = import ../../../lib/shared/targets.nix {
    inherit (inputs) self nixpkgs nixpkgs-unstable;
    inherit inputs;
  };
  base = targets.base;
  legacyAlias = "${base.user.username}-${base.platform.tag}";

  nixosFace = builtins.attrNames targets.nixosConfigurations;
  homeFace = builtins.attrNames targets.homeConfigurations;
  darwinFace = builtins.attrNames targets.darwinConfigurations;

  # arch is a pipeline VALUE (the pkgs synthesis input), never an
  # address: no face key may carry an arch tag. Same platform +
  # different arch → two closures named by their directories, each
  # with its own pkgs instance (the per-host arch discipline).
  # __variants__ is the enum table's canonical tag list (the table
  # itself carries helper attrs — match/serialize — that are not
  # instances; attrValues over it would hit them).
  archTags = base.enum.arch.__variants__;

  # The loader's contract: hostName answers the directory loaded.
  misaligned = builtins.filter (h: (hostShared h).hostName != h) hostNames;

  faceDiff =
    expected: actual:
    (map (k: "face is missing '${k}'") (builtins.filter (k: !builtins.elem k actual) expected))
    ++ (map (k: "face carries unexpected '${k}'") (
      builtins.filter (k: !builtins.elem k expected) actual
    ));

  namingIssues =
    # 1. Law G proper: the alias may never shadow a real host.
    (
      if builtins.elem legacyAlias hostNames && legacyAlias != base.hostName then
        [
          "hosts/${legacyAlias}/ exists — the legacy output alias '${legacyAlias}' would shadow it (rename the directory, or change the fleet identity so the alias does not collide)"
        ]
      else
        [ ]
    )
    # 2. nixosConfigurations keys == the nixosHosts + the alias.
    ++ (faceDiff (targets.inventory.nixosHosts ++ [ legacyAlias ]) nixosFace)
    # 3. homeConfigurations keys == "<user>@<host>" over the
    #    standaloneHosts, per-host usernames (the open host layer
    #    may override user — the face follows the override).
    ++ (faceDiff (map (
      h: "${(hostShared h).user.username}@${h}"
    ) targets.inventory.standaloneHosts) homeFace)
    # 4. darwinConfigurations keys == the darwinHosts.
    ++ (faceDiff targets.inventory.darwinHosts darwinFace)
    # 5. arch never names anything.
    ++ (map (k: "face key '${k}' carries an arch tag — arch is a pipeline value, never an address") (
      builtins.filter (k: builtins.any (a: lib.hasInfix a k) archTags) (
        nixosFace ++ homeFace ++ darwinFace
      )
    ))
    # 6. hostName force-alignment, per host.
    ++ (map (
      h:
      "hosts/${h}/ policy answers hostName '${(hostShared h).hostName}' — the loader's force-alignment is broken"
    ) misaligned);

  namingVerdict =
    if namingIssues == [ ] then
      "naming lawful — Law G (the legacy alias '${legacyAlias}' shadows nothing) held; the faces key exactly by inventory (nixos ${toString (builtins.length nixosFace)}, home ${toString (builtins.length homeFace)}, darwin ${toString (builtins.length darwinFace)}); no face name carries an arch tag; hostName aligned on all ${toString (builtins.length hostNames)} hosts"
    else
      throw ''
        naming census violations (Law G):
        ${lib.concatStringsSep "\n" (map (l: "  ${l}") namingIssues)}

        Directory names own the output namespaces (per-kind unique, a
        symbol table): nixosConfigurations.<dir> plus the ONE legacy
        alias <user>-<platform> — guarded, it may never shadow a real
        host directory; homeConfigurations."<user>@<dir>";
        darwinConfigurations.<dir>; colmena nodes = nixosHosts (pinned
        by lib_shared_deploy). arch is a pkgs-synthesis VALUE and never
        enters a name; the loader force-aligns hostName to the directory
        it loaded. See lib/shared/targets.nix (the Law G guard) and
        mechanisms.md §3 (the naming model).'';
in
{
  name = "lib_shared_targets";
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

    with subtest("targets: fact-source census — every host declares its hardware facts in exactly the shape its platform consumes"):
        # ${censusVerdict} — renders only if every host answered the
        # census lawfully; the machine itself is a dummy.
        machine.succeed("true")

    with subtest("targets: naming census — directory names own the output namespaces, the alias never shadows, arch never names"):
        # ${namingVerdict} — renders only if every face answered the
        # naming lawfully; the machine itself is a dummy.
        machine.succeed("true")
  '';
}
