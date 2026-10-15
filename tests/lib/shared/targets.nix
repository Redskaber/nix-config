# @path: ~/projects/configs/nix-config/tests/lib/shared/targets.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: tests::lib::shared::targets — the fact-source census
# @source: lib/shared/targets.nix (host classification) × hosts/ (machine facts)
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
#
# Construction discipline (the wsl.nix precedent): each host's policy is
# built exactly like targets.nix mkShared — same loader, same args, same
# hostName — so the census reads the SAME caps the classifier reads;
# hosts/ is enumerated the same way the inventory frontend enumerates
# it. File presence IS the declaration (the data-and-interpreter
# split taken to its conclusion): a fact source that exists but is not
# wired is still counted — that is the point.
#
# Mutation check: delete hosts/nixos/hardware.nix without flipping the
# wiring → Law B fires with the host named; park a stray hardware.nix in
# hosts/darwin → Law C fires; leave both files mid-migration → Law A
# fires with both named.

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
  '';
}
