# @path: ~/projects/configs/nix-config/tests/lib/shared/deploy.nix
# @author: redskaber
# @datetime: 2026-10-11
# @description: tests::lib::shared::deploy — the deploy-face census (T21.1)
# @source: lib/shared/targets.nix (the colmena emitter) × hosts/ (deploy facts)
#
# T20.1 shipped the fourth emitter (colmenaHive) with its census law
# verified by static simulation only — this test locks the properties
# the simulation argued, against the REAL tree, through the SAME
# lenses the emitter reads (the T19.1 construction discipline):
#
#   Law D (no lying deploy facts) — a deploy.nix on a host outside the
#       classifier's nixosHosts is a lying file: colmena deploys the
#       nixosHosts only (darwin keeps darwin-rebuild, standalone
#       home-only hosts keep home-switch), so the loader throws at
#       eval instead of silently ignoring dead data. The census fires
#       on file presence, imported or not — same family as T19.1's
#       fact-source laws (a fact source nobody consumes is dead
#       data; a deploy fact nobody can deploy is the same lie).
#   Emission coverage — colmenaHive's node set IS the classifier's
#       nixosHosts, both directions: every NixOS host joined the
#       deploy face by construction (inventory-driven, zero hardcoded
#       member tables — the T18.1 convention), and nothing else snuck
#       into the hive. A drift here means someone hand-wrote a node.
#   The user door — every nixosHost's targetUser derives from its
#       policy (user.username): empty or "root" is a dead door. ssh.nix
#       pins PasswordAuthentication=false and PermitRootLogin="no",
#       so colmena's stock targetUser "root" cannot log in — the
#       policy user is the only way in.
#
# Construction discipline (the wsl.nix/T19.1 precedent): policy
# handles are built exactly like targets.nix mkShared — same loader,
# same args, same hostName — and the emitter is imported the way
# faces.nix imports it. colmenaHive.nodes is forced ONLY through
# attrNames: the lazy chain (nodeNames → attrNames hive → union keys)
# never evaluates a single NixOS module tree. The drvPath parity
# claim belongs to the CI gate (.github/workflows/ci.yml
# host-toplevels), not to a VM test.
#
# Mutation check: park a deploy.nix in hosts/darwin/<h>/ → Law D
# fires with the host named (the emitter's own loader throws at eval
# too — this census catches the lie on the same tree); hand-write a
# node into the hive's node list → coverage fires naming the
# intruder; drop a NixOS host from the hive → coverage fires naming
# the absentee; set a host's username to "root" → the user door fires
# with the policy path named.

{
  inputs,
  shared,
  pkgs,
  lib,
  ...
}:
let
  # ── the REAL host policies, the classifier's own construction ──────
  # (lazy attrs: forcing only .caps/.user keeps the unforced channels
  # free — the same discipline the T19.1 census follows)
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

  # The classifier's own answer to "what does colmena deploy" — the
  # same lens the emitter's `byCap (caps: caps.nixos-system)` reads.
  nixosHosts = builtins.filter (h: (hostShared h).caps.nixos-system) hostNames;

  # ── the emitter itself, imported the way faces.nix imports it ───────
  hostTargets = import ../../../lib/shared/targets.nix {
    inherit (inputs) self nixpkgs nixpkgs-unstable;
    inherit inputs;
  };

  # ── Law D: lying deploy facts ──────────────────────────────────────
  # File presence IS the declaration; the consumer set is the
  # classifier's nixosHosts. A deploy.nix on a host outside that set
  # is dead data the loader would refuse — named here BEFORE the
  # emitter ever forces it.
  deployViolations =
    map
      (
        h:
        "  ${h}: carries deploy.nix but sits outside the nixosHosts — colmena's scope is the nixosHosts; darwin deploys via darwin-rebuild, standalone home-manager hosts via home-switch"
      )
      (
        builtins.filter (
          h: !(hostShared h).caps.nixos-system && builtins.pathExists (hostsDir + "/${h}/deploy.nix")
        ) hostNames
      );

  # ── emission coverage: the hive mirrors the classifier ────────────
  # attrNames only — see the header's laziness note. Both directions,
  # because an emitter that drops a host is as broken as one that
  # invents one.
  hiveNodes = builtins.attrNames hostTargets.colmenaHive.nodes;
  missingFromHive = builtins.filter (h: !builtins.elem h hiveNodes) nixosHosts;
  extraInHive = builtins.filter (n: !builtins.elem n nixosHosts) hiveNodes;

  # ── the user door: targetUser must be a living policy user ────────
  # mkColmenaNode writes `deployment.targetUser = cshared.user.username`
  # — the same expression this lens reads. Empty or "root" means the
  # deploy face has no door at all (ssh.nix pins PasswordAuthentication
  # =false, PermitRootLogin="no").
  userViolations =
    map
      (
        h:
        "  ${h}: policy username is \"${(hostShared h).user.username}\" — empty or root leaves colmena no way in (ssh.nix pins PasswordAuthentication=false, PermitRootLogin=\"no\")"
      )
      (
        builtins.filter (
          h:
          let
            u = (hostShared h).user.username;
          in
          u == "" || u == "root"
        ) nixosHosts
      );

  coverageLines =
    (map (
      h:
      "  ${h}: a nixosHost absent from colmenaHive — the deploy face dropped a host the classifier still counts"
    ) missingFromHive)
    ++ (map (
      n:
      "  ${n}: a hive node the classifier never emitted — someone hand-wrote a node into the deploy face"
    ) extraInHive);

  allViolations = deployViolations ++ coverageLines ++ userViolations;

  deployCensusVerdict =
    if allViolations == [ ] then
      "all ${toString (builtins.length hostNames)} hosts lawful — Law D (no lying deploy facts) held over ${toString (builtins.length nixosHosts)} nixosHosts, emission coverage exact (colmenaHive nodes == the classifier's nixosHosts, ${toString (builtins.length hiveNodes)} of ${toString (builtins.length nixosHosts)}), the user door held (no root, no empty)"
    else
      throw ''
        deploy-face census violations (T21.1):
        ${lib.concatStringsSep "\n" allViolations}

        Deploy facts (hosts/<h>/deploy.nix) are host facts only a
        nixosHost can consume; the hive is the classifier's nixosHosts
        re-emitted, nothing more; and every node's targetUser must be
        the host's policy user. See tests/lib/shared/deploy.nix's
        header for the laws and the mutation checks.'';
in
{
  name = "lib_shared_deploy";
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

    with subtest("deploy: the deploy-face census — every deploy fact lives on a host colmena can consume, the hive mirrors the classifier exactly, every node's user door is alive"):
        # ${deployCensusVerdict} — renders only if every law held; the
        # machine itself is a dummy (the laws are eval-time properties).
        machine.succeed("true")
  '';
}
