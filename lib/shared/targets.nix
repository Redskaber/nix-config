# @path: ~/projects/configs/nix-config/lib/shared/targets.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: lib::shared::targets — host→closure target factory (T5.1)
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
#
# Producer side of the flake outputs (the backend pass): flake.nix
# declares INPUTS and maps flake-protocol names; everything between
# "a hosts/ directory" and "ready-to-build closures" happens HERE, in
# one compiler-shaped pipeline:
#
#   frontend    hostsInventory   readDir hosts/ — mkdir adds a host,
#   (scan)                      no flake.nix edit (T2.3/T2.4)
#
#   middle      classifyHosts    capability-table queries — the enum.nix
#   (IR pass)                   caps vectors decide the host class;
#                               zero if-else, zero raw tag compares
#                               (T4.0; later passes query the target
#                               description, never re-lex it)
#
#   backend     mkNixosSystem    target emitters — one policy graph in,
#   (codegen)  mkDarwinSystem   several closure formats out (a compiler
#              mkHomeSystem      links one IR into multi-target
#                               artifacts; the flake links one policy
#                               graph into nixos / darwin / standalone-HM
#                               closures)
#
# The consumer (flake.nix) only writes:
#
#   targets = import ./lib/shared/targets.nix { … };
#   inherit (targets) nixosConfigurations homeConfigurations darwinConfigurations;
#
# Adding a target format = adding an emitter here; adding a host =
# mkdir under hosts/; changing a host's class = editing
# hosts/<h>/shared.nix. None of those ever edit flake.nix.

{
  self,
  nixpkgs,
  nixpkgs-unstable,
  inputs,
  ...
}:
let
  lib = nixpkgs.lib;

  # Base policy instance (the default host) — the legacy output alias
  # stays anchored to it, exactly like the flake-level shared handle.
  shared = import ./default.nix {
    inherit
      self
      nixpkgs
      nixpkgs-unstable
      inputs
      ;
  };
  pkgs = shared.pkgs;

  # ── frontend: host inventory (T2.3/T2.4) ──────────────────────
  # Enumerated from hosts/ — adding a machine is mkdir + files. Each
  # host gets its own policy-scoped `shared` (base shared.nix ⊕
  # hosts/<host>/shared.nix overrides).
  hostNames = builtins.attrNames (
    lib.filterAttrs (_: t: t == "directory") (builtins.readDir ../../hosts)
  );

  mkShared =
    host:
    import ./default.nix {
      inherit
        self
        nixpkgs
        nixpkgs-unstable
        inputs
        ;
      hostName = host;
    };

  # ── The policy IR, instantiated ONCE per host (T5.10) ──────────
  # Common-subexpression elimination at the dispatch layer. Before
  # this table, every consumer re-ran the whole two-phase loader:
  # three capability queries, every emitter, the output naming and
  # the legacy alias each called mkShared afresh — ~23 policy-graph
  # constructions for four hosts, every one re-importing the lang
  # front-end, re-validating the schema and (when forced past .caps)
  # re-instantiating BOTH nixpkgs channels. A compiler hoists loop
  # invariants; the dispatch layer instantiates the IR once per
  # compilation unit and passes the HANDLE around. Lazy attrs keep
  # unforced hosts free — a closure that never asks for host X never
  # pays for X — and the DEFAULT host's entry IS the base instance
  # above (hostName = null resolves to the same files, so the values
  # are identical; sharing the handle just means the base host is
  # never paid for twice).
  sharedByHost = (lib.genAttrs hostNames mkShared) // {
    ${shared.hostName} = shared;
  };

  # ── middle: capability classification (T4.0) ──────────────────
  # The inventory is heterogeneous: NixOS machines, a wsl standalone-HM
  # host and a darwin host link through DIFFERENT output sections.
  # Routing queries the platform capability table (enum.nix caps
  # vectors) instead of raw tag strings — the entry layer and the
  # leaves read the SAME dispatch table, and a host changes class by
  # editing hosts/<h>/shared.nix, not this file.
  hostCaps = h: sharedByHost.${h}.caps;
  byCap = cap: builtins.filter (h: cap (hostCaps h)) hostNames;

  nixosHosts = byCap (caps: caps.nixos-system);
  darwinHosts = byCap (caps: caps.darwin);
  # Standalone home-manager stays meaningful on generic-Linux-class
  # tags; darwin hosts get their HM through the darwin module instead
  # (a darwin standalone closure would otherwise carry linux pkgs).
  standaloneHosts = byCap (caps: !caps.darwin);

  # ── backend: target emitters (codegen) ────────────────────────
  # One policy graph in, three closure formats out. Directory
  # grammar v3 — directory-as-domain (T5.11): a platform directory
  # splits its two option universes by LEVEL, and every import
  # syntax below is a uniform directory reference — the subtree
  # owns its whole shape (T5.4 principle, now universal):
  #
  #   platform/<tag>/default.nix   the SYSTEM door — the platform's
  #                                top level IS the system domain.
  #                                Present IFF the platform has a
  #                                system form (nixos · darwin; absent
  #                                on linux/wsl — no system emitter
  #                                ever asks for them)
  #   platform/<tag>/<subsys>/     the system tree (core/ dm/ wm/…) —
  #                                grows free at the top level
  #   platform/<tag>/home/         THE user domain of the platform —
  #                                reserved top-level name (the one
  #                                word v3 reserves): every HM file
  #                                lives one level down, never flat
  #                                at the system level
  #   platform/<tag>/home/default.nix
  #                                the HOME door — present IFF the
  #                                platform keeps a standalone HM
  #                                closure live (nixos · linux · wsl;
  #                                absent on darwin — HM rides in
  #                                module mode inside the system
  #                                closure, T5.8)
  #   platform/<tag>/home/<arch>.nix
  #                                HM payload — arch rows, organized
  #                                INSIDE the user domain. The target
  #                                double: the platform axis picks
  #                                the directory, the arch axis picks
  #                                the row (system-level arch
  #                                differences are absorbed by the
  #                                emitter's `system` parameter at
  #                                the nixpkgs layer — the arch axis
  #                                exists ONLY in the user domain, so
  #                                v3 gives it an address there)
  #
  #   mkNixosSystem   platform/<tag>        → default.nix
  #   mkDarwinSystem  platform/<tag>        → default.nix
  #   mkHomeSystem    platform/<tag>/home   → home/default.nix
  #
  # File presence IS the capability declaration — the caps table
  # (enum.nix) projected onto the filesystem: listing a platform
  # directory reads off its shape, and every PATH has exactly one
  # meaning (v2 read domains off filenames; v3 reads them off
  # levels — top = system, home/ = user, so no same-name-different-
  # domain debt either way). A declared-but-absent path fails loudly
  # at eval; the host's policy decides WHERE the path lands; the
  # caps classifier decides WHO reaches which emitter.
  # Structure never smuggles policy: nixos keeps BOTH doors live
  # ON purpose (standalone HM switches in seconds and rolls back
  # independently of the system generation) — folding them into
  # one file would be a policy flip, not a layout cleanup, and
  # would need option-existence sniffing (config-layer if-else,
  # forbidden).

  mkNixosSystem =
    host:
    let
      nshared = sharedByHost.${host};
    in
    nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        shared = nshared;
      };
      # Directory reference lands in platform/<tag>/default.nix —
      # the system customs (grammar v3, T5.11). The platform's
      # top level IS the system domain (core/ dm/ wm/ grow free
      # there); the sibling home/ subtree serves the platform's
      # OTHER live door (standalone HM) without ever touching
      # this one — two option universes, two levels.
      modules = [ ../../platform/${nshared.platform.tag} ];
    };

  mkHomeSystem =
    host:
    let
      hshared = sharedByHost.${host};
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        inherit inputs;
        shared = hshared;
      };
      # Directory reference lands in platform/<tag>/home/ — the
      # HM customs (grammar v3, T5.11): the user domain of the
      # platform, one level below the system top. Uniform with the
      # two system emitters above — three directory references,
      # each subtree owning its whole shape (the door inside is
      # home/default.nix; standalone-only platforms like linux/wsl
      # have exactly this subtree and no system level at all).
      modules = [ ../../platform/${hshared.platform.tag}/home ];
    };

  # darwinSystem goes through the platform customs (T5.8, grammar
  # v3 T5.11): the darwin platform has ONE live door — the system
  # closure with HM riding inside in module mode — so this directory
  # reference lands in platform/<tag>/default.nix, the system
  # router itself (imports hm.darwinModule + host facts, dispatches
  # the arch payload under home-manager.users). There is no
  # home/default.nix inside its home/ subtree: the standalone HM
  # door does not exist on darwin (file absence = capability
  # declaration — the payload rows still live there, mounted in
  # module mode). Zero module names, zero assembly details at the
  # dispatch layer — one directory reference, and the tree owns
  # its whole shape.
  mkDarwinSystem =
    host:
    let
      dshared = sharedByHost.${host};
    in
    inputs.nix-darwin.lib.darwinSystem {
      system = dshared.arch.tag;
      specialArgs = {
        inherit inputs;
        shared = dshared;
      };
      modules = [ ../../platform/${dshared.platform.tag} ];
    };
in
{
  # Ready-to-use closures — flake.nix maps these 1:1 onto the flake
  # protocol output names. No consumer-side assembly required.

  # The pipeline's base policy IR handle (T5.10): flake.nix consumes
  # THIS instead of importing lib/shared a second time — one base
  # instance across the whole flake evaluation (api.shared, checks,
  # packages, formatter and devShells read the same thunk the
  # emitters' `pkgs` came from, instead of each paying for an
  # identical policy-graph construction).
  base = shared;

  # 'sudo nixos-rebuild --flake <flake_path>#<host> switch'
  nixosConfigurations =
    let
      closures = builtins.listToAttrs (
        builtins.map (h: lib.nameValuePair h (mkNixosSystem h)) nixosHosts
      );
    in
    closures
    // {
      # Legacy alias (pre-T2.4 attr name) kept for existing consumers —
      # an attr-level alias, NOT a re-emission (T5.10): the pre-T5.10
      # code re-ran mkNixosSystem for the base host, paying the whole
      # closure evaluation a second time whenever both names were
      # forced (`nix flake check` evaluated it twice). Aliasing shares
      # the one thunk; the values are identical by purity. Precondition
      # unchanged from before: the base host is nixos-class, or this
      # fails at eval (attr missing — previously: platform door
      # missing — either way loud and immediate).
      "${shared.user.username}-${shared.platform.tag}" = closures.${shared.hostName};
    };

  # 'nix build .#homeConfigurations.<user>@<host>.activationPackage'
  # Available through 'home-manager --flake .#<user>@<host>'
  homeConfigurations = builtins.listToAttrs (
    builtins.map (
      h: lib.nameValuePair "${sharedByHost.${h}.user.username}@${h}" (mkHomeSystem h)
    ) standaloneHosts
  );

  # 'darwin-rebuild switch --flake .#<host>' — evaluation of the darwin
  # closure is exercised from any builder platform; 'switch' itself
  # needs a darwin host.
  darwinConfigurations = builtins.listToAttrs (
    builtins.map (h: lib.nameValuePair h (mkDarwinSystem h)) darwinHosts
  );

  # Inventory surface (debug/CI): what the classifier saw. Exposed by
  # flake.nix as api.targets — `nix eval .#api.targets.inventory`.
  inventory = {
    inherit
      hostNames
      nixosHosts
      darwinHosts
      standaloneHosts
      ;
  };
}
