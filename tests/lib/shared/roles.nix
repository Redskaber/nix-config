# @path: ~/projects/configs/nix-config/tests/lib/shared/roles.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: tests::lib::shared::roles — the three-layer chain contract
# @source: lib/shared/default.nix (controlled merge) × lib/shared/lang/enum.nix (role table)
#          × shared.nix (fleet registry) × hosts/ (host layer)
#
# The policy chain is fleet → role → host, and every law that keeps
# it honest is locked HERE, against the REAL production handle (the
# targets.nix construction discipline: same loader, same args, same
# hostName — no mocks):
#
#   Law E (zero drift, both ways) — the fleet registry (shared.nix →
#       roles) and the hosts/ directory carry EXACTLY the same host
#       set. A registry row without a directory is a ghost (the
#       management plane lies about the fleet); a directory without
#       a registry row is an unassigned host (the loader would
#       throw at eval time — this catches it before that, with the
#       name in the CI log).
#   Law F (closed whitelist)      — every role row of the enum
#       carries strategy keys ONLY. Identity keys belong to fleet,
#       class keys to host; a leaking key is a layering violation
#       that would die at the merge point — the census here names
#       the row AND the keys.
#   Equivalence locks             — the per-host merged results are
#       pinned to their pre-migration values (the P0/P1 migration
#       proof): what each host consumes is byte-for-byte what it
#       consumed before the three-layer chain, EXCEPT the two
#       documented deltas below.
#   P1.5 (bias fix)               — the console-family hosts now
#       run the minimal service profile: a WSL distro no longer
#       silently installs four databases (the pre-role inheritance
#       artefact). vm keeps server-pg-only; nixos keeps
#       dev-on-demand.
#   `why` (provenance)            — the loader stamps every merged
#       key with its winning layer; the handle answers
#       shared.why.<key> (git-config's --show-origin).
#
# Documented deltas vs the pre-role chain (both deliberate, both
# named in the migration notes):
#   · wsl / nixos-wsl display-manager: ly → none. The dm axis has
#     ZERO consumers when wm = none — the value was dead weight
#     inherited from the pre-role base; the console role now
#     declares the Null-Object row explicitly.
#   · wsl / nixos-wsl service-profile: dev-on-demand → minimal
#     (the P1.5 bias fix above).

{
  inputs,
  shared,
  pkgs,
  lib,
  ...
}:
let
  # ── the REAL host policies, the classifier's own construction ──────
  # (lazy attrs: forcing only data keys keeps the unforced channels
  # free — the targets.nix discipline)
  hostShared =
    h:
    import ../../../lib/shared {
      inherit (inputs) self nixpkgs nixpkgs-unstable;
      inherit inputs;
      hostName = h;
    };

  nix = hostShared "nixos";
  vm = hostShared "vm";
  wsl = hostShared "wsl";
  nixos-wsl = hostShared "nixos-wsl";
  darwin = hostShared "darwin";

  # ── the hosts/ frontend, the inventory's own enumeration ───────────
  hostsDir = ../../../hosts;
  hostDirs = builtins.attrNames (
    lib.filterAttrs (_: t: t == "directory") (builtins.readDir hostsDir)
  );

  # ── the fleet registry, read off the production handle ─────────────
  registryNames = builtins.attrNames shared.roles;

  # Law E — zero drift in BOTH directions.
  ghosts = lib.subtractLists hostDirs registryNames;
  unassigned = lib.subtractLists registryNames hostDirs;
  lawE =
    if ghosts != [ ] then
      throw "roles Law E: fleet registry carries hosts with no directory: ${toString ghosts}"
    else if unassigned != [ ] then
      throw "roles Law E: hosts/ directories with no registry row (no role assigned): ${toString unassigned}"
    else
      true;

  # ── Law F — the closed whitelist, every role row ───────────────────
  role-policy-keys = shared.enum.role-policy-keys;
  lawF =
    map
      (
        row:
        let
          leak = lib.subtractLists role-policy-keys (builtins.attrNames row.value);
        in
        if leak != [ ] then
          throw "roles Law F: role '${row.tag}' carries non-strategy keys: ${toString leak} (allowed: ${toString role-policy-keys})"
        else
          true
      )
      (
        with shared.enum.role;
        [
          workstation
          console
          server
          laptop
        ]
      );

  # ── eval-time assertions (the migration proof) ─────────────────────
  evalAssertions =
    # Law E + Law F hold.
    assert lawE;
    assert builtins.all (lib.id) lawF;

    # The registry itself: five hosts, the roles they always had.
    assert shared.roles.nixos.tag == "workstation";
    assert shared.roles.vm.tag == "server";
    assert shared.roles.wsl.tag == "console";
    assert shared.roles.nixos-wsl.tag == "console";
    assert shared.roles.darwin.tag == "laptop";

    # ── nixos: the workstation — full form, unchanged ────────────────
    assert nix.platform.tag == "nixos";
    assert nix.window-manager.tag == "hyprland";
    assert nix.display-manager.tag == "ly";
    assert nix.drive.tag == "intel";
    assert nix.sound.tag == "pipewire";
    assert
      nix.editor-set.value.editors == [
        "nvim"
        "vscode"
        "cursor"
        "zed"
        "emacs"
        "kiro"
      ];
    assert
      nix.terminal-set.value.terminals == [
        "kitty"
        "wezterm"
      ];
    assert
      nix.browser-set.value.browsers == [
        "google-chrome"
        "qutebrowser"
        "w3m"
      ];
    assert builtins.length nix.app-set.value.categories == 16;
    assert nix.service-profile.value.db.postgresql.install == true;
    assert nix.service-profile.value.db.mysql.install == true;

    # ── vm: the server — console form + pg heart + the one
    # specialisation (browser pair) ──────────────────────────────────
    assert vm.platform.tag == "nixos";
    assert vm.window-manager.tag == "none";
    assert vm.display-manager.tag == "none";
    assert vm.drive.tag == "amd";
    assert vm.sound.tag == "pipewire";
    assert vm.editor-set.value.editors == [ "nvim" ];
    assert vm.terminal-set.value.terminals == [ "kitty" ];
    assert
      vm.browser-set.value.browsers == [
        "google-chrome"
        "qutebrowser"
      ];
    assert
      vm.app-set.value.categories == [
        "browser"
        "editor"
        "terminal"
      ];
    assert vm.service-profile.value.db.postgresql.install == true;
    assert vm.service-profile.value.db.postgresql.autostart == true;
    assert vm.service-profile.value.db.mysql.install == false;

    # ── wsl: the console — Null-Object forms, minimal services
    # (P1.5: the db inheritance bias is gone) ─────────────────────────
    assert wsl.platform.tag == "wsl";
    assert wsl.window-manager.tag == "none";
    assert wsl.display-manager.tag == "none";
    assert wsl.drive.tag == "amd";
    assert wsl.editor-set.value.editors == [ "nvim" ];
    assert wsl.terminal-set.value.terminals == [ "kitty" ];
    assert wsl.browser-set.value.browsers == [ "w3m" ];
    assert
      wsl.app-set.value.categories == [
        "browser"
        "editor"
        "terminal"
      ];
    # P1.5 — the bias fix: no databases inside a WSL distro.
    assert wsl.service-profile.value.db.postgresql.install == false;
    assert wsl.service-profile.value.db.mysql.install == false;
    assert wsl.service-profile.value.db.redis.install == false;
    assert wsl.service-profile.value.db.mongodb.install == false;
    assert wsl.service-profile.value.monitor.enable == false;

    # ── nixos-wsl: the console, system-owned flavour ──────────────────
    assert nixos-wsl.platform.tag == "nixos-wsl";
    assert nixos-wsl.window-manager.tag == "none";
    assert nixos-wsl.display-manager.tag == "none";
    assert nixos-wsl.drive.tag == "amd";
    assert nixos-wsl.service-profile.value.db.postgresql.install == false;
    assert nixos-wsl.service-profile.value.monitor.enable == false;

    # ── darwin: the laptop — terminal shape, cross-platform trees ────
    assert darwin.platform.tag == "darwin";
    assert darwin.arch.tag == "aarch64-darwin";
    assert darwin.window-manager.tag == "none";
    # Aqua owns the session start too — the dm Null-Object row (the
    # axis stays mandatory in the merged schema; a missing role key
    # here is exactly the eval-caught defect this lock now pins).
    assert darwin.display-manager.tag == "none";
    assert darwin.editor-set.value.editors == [ "nvim" ];
    assert darwin.terminal-set.value.terminals == [ "kitty" ];
    assert darwin.browser-set.value.browsers == [ "w3m" ];
    assert builtins.elem "office" darwin.app-set.value.categories;
    assert builtins.elem "re" darwin.app-set.value.categories;
    assert darwin.service-profile.value.db.postgresql.install == false;

    # ── `why` (provenance): the winning layer, named ─────────────────
    # nixos: the form comes from the role, the class from the host,
    # the identity from the fleet, hostName from the loader.
    assert nix.why.window-manager == "role";
    assert nix.why.display-manager == "role";
    assert nix.why.service-profile == "role";
    assert nix.why.platform == "host";
    assert nix.why.user == "fleet";
    assert nix.why.sound == "fleet";
    assert nix.why.hostName == "loader";
    # vm: the one true specialisation is host-layer; the rest is role.
    assert vm.why.browser-set == "host";
    assert vm.why.service-profile == "role";
    assert vm.why.platform == "host";
    # darwin: class + arch are host facts.
    assert darwin.why.arch == "host";
    assert darwin.why.app-set == "role";
    # The registry rides the handle (the management plane is visible
    # to every consumer). Compared as a function-free projection —
    # enum instances carry match lambdas, and Nix compares distinct
    # functions as unequal (tag-per-host is the registry's identity).
    assert
      builtins.mapAttrs (_: row: row.tag) nix.roles == builtins.mapAttrs (_: row: row.tag) shared.roles;
    "eval-assertions-passed";
in
{
  name = "lib_shared_roles";
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

    with subtest("roles: three-layer chain evaluated with all assertions"):
        # Real loader/registry/role-table were exercised both ways at
        # eval time (${evalAssertions}); the VM only proves the check
        # boots.
        machine.succeed("true")
  '';
}
