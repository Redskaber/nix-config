# @path: ~/projects/configs/nix-config/lib/shared/targets.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: lib::shared::targets — host→closure target factory
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
#
# Producer side of the flake outputs (the backend pass): flake.nix
# declares INPUTS and maps flake-protocol names; everything between
# "a hosts/ directory" and "ready-to-build closures" happens HERE, in
# one compiler-shaped pipeline:
#
#   frontend    hostsInventory   readDir hosts/ — mkdir adds a host,
#   (scan)                      no flake.nix edit
#
#   middle      classifyHosts    capability-table queries — the enum.nix
#   (IR pass)                   caps vectors decide the host class;
#                               zero if-else, zero raw tag compares
#                               (later passes query the target
#                               description, never re-lex it)
#
#   backend     mkNixosSystem    target emitters — one policy graph in,
#   (codegen)  mkDarwinSystem   several closure formats out (a compiler
#              mkHomeSystem      links one IR into multi-target
#              mkColmenaHive    artifacts; the flake links one policy
#                               graph into nixos / darwin / standalone-HM
#                               closures / the colmena deploy face — same
#                               module doors, deployable packaging)
#
# The consumer (lib/shared/faces.nix, the linker pass) only
# writes:
#
#   targets = import ./lib/shared/targets.nix { … };
#   inherit (targets) nixosConfigurations homeConfigurations darwinConfigurations;
#   inherit (targets) colmenaHive hostToplevels darwinToplevels;
#
# (flake.nix itself delegates the whole outputs body to faces.nix —
# the entry layer registers inputs and nothing else.)
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

  # ── frontend: host inventory ──────────────────────────────
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

  # ── The policy IR, instantiated ONCE per host ──────────────
  # Common-subexpression elimination at the dispatch layer: the IR is
  # instantiated once per compilation unit and the HANDLE is passed
  # around. Lazy attrs keep unforced hosts free — a closure that
  # never asks for host X never pays for X — and the DEFAULT host's
  # entry IS the base instance above (hostName = null resolves to the
  # same files; sharing the handle means the base host is never paid
  # for twice).
  sharedByHost = (lib.genAttrs hostNames mkShared) // {
    ${shared.hostName} = shared;
  };

  # ── middle: capability classification ─────────────────────
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
  # grammar v4 — platform-major, domain-explicit: every platform
  # tag owns a directory, and inside it exactly two reserved
  # domain names — system/ and home/ — each with its own
  # default.nix door. The two domains hold SYMMETRIC addresses:
  #
  #   platform/<tag>/system/      the SYSTEM domain — default.nix
  #                               is the system door: entry and
  #                               dispatch for the platform's system
  #                               form; system configs (core/ dm/
  #                               wm/…) grow free around it. Present
  #                               IFF the platform has a system form
  #                               (nixos · darwin · nixos-wsl; absent
  #                               on linux/wsl — no system emitter
  #                               ever asks for them)
  #   platform/<tag>/home/        the USER domain — default.nix is
  #                               the home door: entry and dispatch
  #                               for the user domain; the door IS
  #                               the HM payload module (base facts
  #                               + the cross-platform user library
  #                               imports), present on every platform
  #                               (nixos · linux · wsl · nixos-wsl
  #                               standalone doors; darwin's door is
  #                               mounted by its system customs in
  #                               module mode)
  #
  # The arch axis is NOT modelled anywhere on disk — it is a
  # natural choice made by the dispatch path, not an address: all
  # arches of a platform walk the ONE same pipeline (one flow per
  # platform), and arch differences are absorbed BEFORE these
  # doors, by the emitters' `system` parameter and the per-host
  # pkgs synthesis at the nixpkgs layer (the runtime layer
  # instantiates { system = arch.tag; }). The target double keeps
  # its platform half as a directory address and its arch half as
  # a pipeline VALUE.
  #
  #   mkNixosSystem   platform/<tag>/system → default.nix
  #   mkDarwinSystem  platform/<tag>/system → default.nix
  #   mkColmenaNode   platform/<tag>/system → default.nix
  #   mkHomeSystem    platform/<tag>/home   → default.nix
  #
  # The natural dispatch boundary is exactly where the pipeline
  # lands — default.nix → <system/default.nix | home/default.nix>
  # — and the tag interpolation below is the dispatch layer's own
  # projection (never an if-else, never a raw tag compare): the
  # policy IR carries the tag, the emitters project it onto the
  # filesystem, and the config tree stays free of platform
  # decisions. File presence IS the capability declaration — the
  # caps table (enum.nix) projected onto the filesystem: listing a
  # platform directory reads off its shape, and every PATH has
  # exactly one meaning. A declared-but-absent path fails loudly
  # at eval; the host's policy decides WHERE the path lands; the
  # caps classifier decides WHO reaches which emitter. Structure
  # never smuggles policy: nixos keeps BOTH doors live ON purpose
  # (standalone HM switches in seconds and rolls back
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
      # Directory reference lands in platform/<tag>/system — the
      # platform's system door (grammar v4): the tag arrives from
      # the policy IR and is projected onto the filesystem; the
      # door owns the platform's system form (core/ dm/ wm/ grow
      # free below it), and the user domain has its own symmetric
      # door at platform/<tag>/home.
      modules = [ ../../platform/${nshared.platform.tag}/system ];
    };

  mkHomeSystem =
    host:
    let
      hshared = sharedByHost.${host};
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      # Per-host pkgs: the policy instance already instantiates its
      # nixpkgs for the host's OWN arch (the runtime synthesizes
      # pkgs from pattrs = { system = arch.tag; } ⊕ the nixpkgs
      # policy) — the emitter reads THAT handle instead of the
      # base instance's, so a future aarch64-linux standalone host
      # evaluates against its own arch instead of the base host's.
      pkgs = hshared.pkgs;
      extraSpecialArgs = {
        inherit inputs;
        shared = hshared;
      };
      # Directory reference lands in platform/<tag>/home — the
      # platform's home door (grammar v4): the symmetric twin of
      # the system emitters' reference, one uniform shape for all
      # four emitters. The door IS the HM payload module (arch-free
      # by construction); standalone-only platforms like linux/wsl
      # own exactly this subtree and no system form at all.
      modules = [ ../../platform/${hshared.platform.tag}/home ];
    };

  # darwinSystem goes through the platform customs (grammar v4):
  # the darwin platform has ONE live door — the system closure
  # with HM riding inside in module mode — the same
  # platform/<tag>/system boundary the NixOS emitter takes. That
  # door mounts the user-domain payload (import ../home — the
  # cross-domain reference is explicit in the path) under
  # home-manager.users; no standalone door for darwin exists (the
  # caps classifier never routes a darwin host through
  # platform/<tag>/home).
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
      modules = [ ../../platform/${dshared.platform.tag}/system ];
    };

  # ── backend: deployment facts + the colmena emitter ─────────
  # The fourth closure format: a DEPLOYABLE view of the same hosts.
  # colmena (0.5+, the colmenaHive output protocol) re-evaluates the
  # NixOS module trees itself — the emitter's job is to hand it the
  # SAME module doors the primary emitter takes plus per-host policy
  # handles, so the re-emission stays config-identical (the CI parity
  # gate locks that claim; see .github/workflows/ci.yml host-toplevels).
  #
  # Machine facts: hosts/<h>/deploy.nix — OPTIONAL, the disk.nix/
  # persist.nix family (coordinates are host facts, not policy). File
  # presence IS the declaration "this host carries deploy facts";
  # absent means colmena's own defaults (node name as hostname, port
  # 22). The census law: facts on a host colmena can never consume
  # are a lying file — colmena deploys nixosHosts only (darwin keeps
  # darwin-rebuild, standalone home-only hosts keep home-switch), so
  # the loader throws at eval instead of silently ignoring dead
  # data.
  deployFacts =
    host:
    let
      facts = ../../hosts/${host}/deploy.nix;
    in
    if builtins.pathExists facts then
      (
        if (hostCaps host).nixos-system then
          import facts
        else
          throw ''
            lib::shared::targets — hosts/${host}/deploy.nix: deployment
            facts on a non-NixOS host are a lying file. colmena's scope is
            the nixosHosts (caps.nixos-system); darwin deploys via
            darwin-rebuild, standalone home-manager hosts via home-switch.
            Remove the file, or flip the host's class in
            hosts/${host}/shared.nix.''
      )
    else
      { };

  mkColmenaNode =
    host:
    let
      cshared = sharedByHost.${host};
    in
    {
      # The SAME platform/<tag>/system door the primary emitter takes
      # (grammar v4): colmena's re-emission reads the identical module
      # tree — no parallel assembly to drift. The per-host policy IR
      # arrives through meta.nodeSpecialArgs (colmena injects
      # `name`/`nodes` itself; nothing here duplicates that).
      imports = [ ../../platform/${cshared.platform.tag}/system ];

      # Version identity: the primary emitter rides nixpkgs' FLAKE
      # lib — `nixpkgs.lib.nixosSystem` passes the version-aware lib
      # — while colmena 0.5's hermetic eval imports eval-config.nix
      # RAW (`import (npkgs.path + "/nixos/lib/eval-config.nix")`, no
      # lib argument forwarded — src/nix/hive/eval.nix), where the
      # PLAIN lib answers neither identity field (versionSuffix /
      # revisionWithDefault). Both are restored here, single-sourced
      # from the flake input's own lib — nixpkgs ever changing either
      # computation propagates to both faces together (release /
      # codeName need no lines: both evals read the same .version
      # file; the CI parity gate locks the equivalence).
      system.nixos.versionSuffix = nixpkgs.lib.trivial.versionSuffix;
      system.nixos.revision = nixpkgs.lib.trivial.revisionWithDefault null;

      # Policy-derived default, wholesale-merged UNDER the fact file
      # (hosts/<h>/deploy.nix overrides, the shared.nix ⊕ hosts/ shape):
      # ssh.nix pins PasswordAuthentication=false and PermitRootLogin
      # ="no", so colmena's stock targetUser "root" cannot log in —
      # the policy user is the only way in. Secrets ride sops-nix;
      # colmena's deployment.keys stays unused on purpose.
      deployment = {
        targetUser = cshared.user.username;
      }
      // deployFacts host;
    };

  # ── backend: the closure attrsets, constructed once ───────────
  # The emitters' listToAttrs projections, hoisted out of the output
  # record so the toplevel FACES below (api.host-toplevels /
  # api.darwin-toplevels — what CI hands to nix-fast-build) share the
  # very thunks the *Configurations faces expose: one evaluation of
  # each mk*System call, however many faces address it (the
  # single-instantiation discipline, held at the projection layer
  # too).
  nixosClosures = builtins.listToAttrs (
    builtins.map (h: lib.nameValuePair h (mkNixosSystem h)) nixosHosts
  );
  darwinClosures = builtins.listToAttrs (
    builtins.map (h: lib.nameValuePair h (mkDarwinSystem h)) darwinHosts
  );

  # ── Law G (no shadowed names) — the one synthetic name the ──────
  # pipeline mints, guarded ────────────────────────────────────────
  # The output namespaces key closures by the hosts/ directory name
  # (per-kind unique, a symbol table); the legacy alias
  # `<user>-<platform>` is the ONLY minted name on top of the
  # inventory — and `//` is silent last-wins. Without a guard, a host
  # directory named exactly like the alias would be silently REPLACED
  # by the base host's closure: the name would keep answering
  # `nixos build .#<alias>` while building a DIFFERENT machine's
  # config — a lying name, the worst failure mode. Compilers make
  # same-scope redeclaration a hard error; this is that error. The
  # alias naming its OWN base host (alias == the default hostName) is
  # identity, not shadowing, and stays legal.
  legacyAlias = "${shared.user.username}-${shared.platform.tag}";
  aliasShadow =
    if builtins.elem legacyAlias hostNames && legacyAlias != shared.hostName then
      throw ''
        lib::shared::targets — the legacy output alias '${legacyAlias}'
        would shadow a real host: hosts/${legacyAlias}/ exists and is
        not the base host ('${shared.hostName}'). The alias is reserved
        (an attr-level thunk of the base host's closure for pre-
        multihost consumers). Rename the host directory, or change the
        fleet identity so the alias does not collide. Pinned by the
        naming census (tests/lib/shared/targets.nix, Law G).''
    else
      { };

  # The hive: meta carries the evaluation plumbing, one node attr per
  # nixosHost (inventory-driven — a new NixOS host joins the deploy
  # face by construction, same as every other emitter).
  colmenaHive = inputs.colmena.lib.makeHive (
    {
      meta = {
        # Hermetic mode (colmena 0.5 refuses bare nixpkgs inputs in
        # flakes): an INITIALIZED pkgs set is mandatory. Plain import,
        # no overlays — the nodes' module trees apply overlays exactly
        # where the primary emission applies them, so nothing gets
        # layered twice (mkBefore of an empty overlays list is a
        # no-op inside colmena's injected nixpkgs module).
        nixpkgs = import nixpkgs { system = shared.arch.tag; };

        # Per-host pkgs pins: multi-arch by construction — an
        # aarch64-linux NixOS host would evaluate against its own
        # arch, not the base host's (the per-host-arch discipline,
        # applied at the deploy face).
        nodeNixpkgs = builtins.listToAttrs (
          builtins.map (
            h: lib.nameValuePair h (import nixpkgs { system = sharedByHost.${h}.arch.tag; })
          ) nixosHosts
        );

        # Mirrors the primary emitters' contract: `inputs` for every
        # node; the per-host policy IR handle per node — the same
        # sharedByHost thunks the primary emitters read (single
        # instantiation holds across the re-emission).
        specialArgs = { inherit inputs; };
        nodeSpecialArgs = builtins.listToAttrs (
          builtins.map (h: lib.nameValuePair h { shared = sharedByHost.${h}; }) nixosHosts
        );
      };
    }
    // builtins.listToAttrs (builtins.map (h: lib.nameValuePair h (mkColmenaNode h)) nixosHosts)
  );
in
{
  # Ready-to-use closures — faces.nix maps these 1:1 onto the flake
  # protocol output names. No consumer-side assembly required.

  # The pipeline's base policy IR handle: faces.nix consumes THIS
  # instead of importing lib/shared a second time — one base
  # instance across the whole flake evaluation (api.shared, checks,
  # packages, formatter and devShells read the same thunk the
  # emitters' `pkgs` came from, instead of each paying for an
  # identical policy-graph construction).
  base = shared;

  # 'sudo nixos-rebuild --flake <flake_path>#<host> switch'
  nixosConfigurations =
    # Legacy alias kept for existing consumers — an attr-level
    # alias, NOT a re-emission: aliasing shares the one thunk; the
    # values are identical by purity. Precondition: the base host
    # is nixos-class, or this fails at eval (loud and immediate).
    # Law G rides FIRST in the merge: forcing this attrset's names
    # forces the shadow check before the alias can silently win.
    aliasShadow
    // nixosClosures
    // {
      ${legacyAlias} = nixosClosures.${shared.hostName};
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
  darwinConfigurations = darwinClosures;

  # ── toplevel projections: the CI build faces, produced where ──
  # the closures they read from are produced. api.host-toplevels is
  # the Linux system-toplevel face — the x86_64-linux legs keep the
  # cheap cross-system eval force, the Host Toplevels leg builds
  # the whole face for closure-level depth. Both projections read
  # the hoisted closure attrsets above (each mk*System evaluated once
  # however many faces force it).
  hostToplevels = builtins.listToAttrs (
    builtins.map (h: lib.nameValuePair h nixosClosures.${h}.config.system.build.toplevel) nixosHosts
  );

  # api.darwin-toplevels — the nix-darwin toplevels (what
  # `darwin-rebuild` builds), consumed by CI's darwin leg on a
  # macos-latest (aarch64) runner.
  darwinToplevels = builtins.listToAttrs (
    builtins.map (h: lib.nameValuePair h darwinClosures.${h}.system) darwinHosts
  );

  # The deployable view: what `colmena` reads —
  # `colmenaHive = makeHive { meta; <node per nixosHost> }`. Exposed
  # by faces.nix under the output name colmena 0.5 expects. Scope is
  # the classifier's nixosHosts; a fresh deployment fact file joins
  # by mkdir (hosts/<h>/deploy.nix), no flake.nix edit.
  colmenaHive = colmenaHive;

  # Inventory surface (debug/CI): what the classifier saw. Exposed by
  # faces.nix as api.targets — `nix eval .#api.targets.inventory`.
  inventory = {
    inherit
      hostNames
      nixosHosts
      darwinHosts
      standaloneHosts
      ;
  };
}
