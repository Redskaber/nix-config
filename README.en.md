# nix-config

> Declarative, reproducible, multi-platform management of systems and dev environments
>
> Author: [@Redskaber](https://github.com/Redskaber) · Built on Nix Flakes + Home Manager + SOPS-Nix + nix-darwin + disko
>
> English mirror of [README.md](README.md) — the Chinese original is the canonical source. English docs mirror: [docs/en/](docs/en/).

---

## Table of contents

1. [Preview](#preview)
2. [Architecture overview](#architecture-overview)
3. [Design principles](#design-principles)
4. [Directory grammar — the distribution layer's grammar](#directory-grammar--the-distribution-layers-grammar)
5. [Directory structure](#directory-structure)
6. [Core mechanisms](#core-mechanisms)
7. [Quick start](#quick-start)
8. [Cross-platform support](#cross-platform-support)
9. [Test system](#test-system)
10. [CI/CD complete execution flow](#cicd-complete-execution-flow)
11. [Daily operations quick reference](#daily-operations-quick-reference)
12. [Known boundaries and design debt](#known-boundaries-and-design-debt)
13. [Roadmap](#roadmap)
14. [Deep-dive documentation](#deep-dive-documentation)

> Deep-dive content is layered by audience into `docs/` ([index at the end](#deep-dive-documentation)): architecture internals · the full six-Phase walkthrough ·
> the nine-scenario secrets manual · the complete 98-recipe reference · the CI deep-dive manual — the README keeps only the entry layer.

---

## Preview

<details>
<summary>part tools summary</summary>

![preview_0](./docs/preview/preview_0.png)

![preview_2](./docs/preview/preview_2.png)

![preview_5](./docs/preview/preview_5.png)

![preview_3](./docs/preview/preview_3.png)

![preview_1](./docs/preview/preview_1.png)

![preview_4](./docs/preview/preview_4.png)

![preview_6](./docs/preview/preview_6.png)

</details>

---

## Architecture overview

The system follows a strictly layered pipeline architecture: every layer has a single responsibility and clear boundaries, and dependencies flow in one direction only — top down.

```
┌────────────────────────────────────────────────────────────┐
│  ENTRY LAYER  ·  flake.nix                                 │
│  unified entry · input declaration · one-line handoff      │
│  to faces.nix · api.inputs (targets built in SHARED LAYER) │
└──────────┬──────────────────────────────┬──────────────────┘
           │                              │
┌──────────▼──────────┐       ┌───────────▼──────────────────┐
│  SYSTEM LAYER       │       │  USER LAYER                  │
│  platform/<tag>/    │       │  platform/<tag>/home/        │
│  system/default.nix │       │  home/default.nix (gate IS   │
│  hardware · drivers │       │  the payload; arch retired)  │
│  core/ · dm/ · wm/  │       │  apps · dev environments ·   │
│  security · services│       │  window managers; home/: the │
│ (domain-explicit)   │       │  shared library (core·env·wm)│
│                     │       │  user-domain nix plane (     │
│                     │       │  caps-gated user-level       │
│                     │       │  nix.conf + registry, only in│
│                     │       │  standalone form)            │
└──────────┬──────────┘       └───────────┬──────────────────┘
           │                              │
           │      ┌───────────────────────▼──────────────────┐
           │      │  HOST DISPATCH LAYER  ·  platform/       │
           │      │  platform dir = machine description      │
           │      │  (platform half of target double; arch   │
           │      │  half = pipeline value): platform-major ·│
           │      │  domain-explicit: system/ = system       │
           │      │  domain (default.nix = gate, system-form │
           │      │  only); home/ = user domain (gate IS     │
           │      │  payload) · file existence = capability  │
           │      └───────────────────────┬──────────────────┘
           │                              │
┌──────────▼──────────────────────────────▼──────────────────┐
│  SHARED LAYER  ·  lib/shared/                              │
│  two-stage init: lang (frontend) → runtime (IR synthesis)  │
│  controlled 3-layer merge: fleet (schema.fleet             │
│  self-check) ⊕ role (Law F whitelist) ⊕ host (open)        │
│  → schema.shared 18-key re-validation + per-key why        │
│  target factory targets.nix: hosts/ inventory → caps       │
│  classification → four closure emitters: nixos / darwin /  │
│  standalone-HM / colmena Hive + two toplevel projections;  │
│  the link layer faces.nix: five-gate checks / module-docs /│
│  pdsh / tests built once (production: faces.nix writes only│
│  inherit (targets) ...; policy IR once per host)           │
│  const.nix = identity SSOT (fleet cache: by-value to three │
│  faces + entry-layer silence — cache-ssot's three bans     │
└──────────────────────────────┬─────────────────────────────┘
                               │
┌──────────────────────────────▼─────────────────────────────┐
│  SECRET LAYER  ·  secrets/ + .sops.yaml                    │
│  Age-ciphered · SOPS · least privilege · runtime injection │
│  TMPL → KEY → RULE → PLAIN → CIPHER → /run/secrets/        │
└──────────────────────────────┬─────────────────────────────┘
                               │
┌──────────────────────────────▼─────────────────────────────┐
│  TEST LAYER  ·  tests/                                     │
│  6 planes · 103 tests + 6 repo hygiene gates = 109 checks  │
│         · nmt (zero VM) + QEMU · CI whole-plane handoff    │
└────────────────────────────────────────────────────────────┘
```

**Data flow (the pipeline):**

```
shared.nix (fleet-layer policy: identity · majority defaults · the roles
            registry — schema.fleet 16-key self-check)
    ↓ just shared-generate (template → artifact, overwrite in place)
hosts/<h>/shared.nix (host layer: class keys + specialisation; optional file, the open escape hatch)
    ↓ lib/shared/default.nix controlled three-layer merge: fleet ⊕ role (enum.nix table, Law F whitelist) ⊕ host
      · schema.shared full 18-key re-validation · hostName force-alignment · per-key why provenance
lib/shared (two-stage init: lang → runtime)
    ↓ specialArgs / extraSpecialArgs
lib/shared/targets.nix (target factory: hosts/ inventory → caps classification → emitters)
    ↓ produces finished closures + toplevel projections
lib/shared/faces.nix
    ↓ inherit (targets) nixosConfigurations / homeConfigurations / darwinConfigurations / hostToplevels / darwinToplevels (link layer, R31)
flake.nix → one-line delegation to faces.nix (the entry layer keeps only input registration)
    ↓ three-gate dispatch (data-driven directory references from the emitters; syntax v4: explicit domains):
    ↓   nixos system gate platform/<tag>/system → default.nix
    ↓   · darwin single gate platform/<tag>/system (system routing; HM mounted via import ../home)
    ↓   · HM gate platform/<tag>/home → default.nix (gate IS payload; arch retired)
platform/nixos/{system/{default.nix, core/ dm/ wm/}, home/default.nix} + home/ (module tree; app tree routed by app-set weight class: full/lean/none)
    ↓ sops-nix (initrd stage)
/run/secrets/ (runtime secret mounts)
    ↓ systemd services
the running system
```

**Three-plane distribution of nix.conf (the cross-cutting flow closed):**

```
lib/shared/lang/const.nix — identity SSOT (shared.const.cache.fleet)
    ↓ consumed by value (the eval face cannot drift; R30 closed the last gap — the user plane)
    ├── platform/nixos/.../core/base/nix.nix → nix.settings → /etc/nix/nix.conf (NixOS hosts)
    ├── platform/darwin/system/nix         → nix.settings → /etc/nix/nix.conf (darwin hosts)
    └── home/core/base/nix.nix (caps.system-nix gated; rendered only in standalone form)
                                          → HM nix.settings → ~/.config/nix/nix.conf
                                              (+ nix.registry → registry.json; at build time the
                                                checkPhase validates the syntax with nix config show)
(faces that cannot eval const keep pinned literal mirrors: CI workflows · cachix.just ·
  cache.md prose; the flake.nix entry layer stays silent by statute  —
  tests/cache-ssot.nix pins the mirror, the consumption, and the absence as assertions.
  Priority-chain ruling: user files shadow system files per setting, so the user plane
  renders only on hosts with no system nix — one nix.conf plane per machine, no drift.)
```

---

## Design principles

| Principle | How it shows up |
| ------------ | ------------------------------------------------------------------------------------------------------------- |
| **Dependency inversion** | `lib/shared` defines the abstract schema/enum; upper-layer modules depend on the abstract interface, not on concrete implementations; `shared` is injected as specialArgs |
| **Pipeline flow** | `shared.nix → lib/shared → targets → flake → platform/home → modules` — a one-way data flow with no reverse dependencies; a three-stage mirror-compiler pipeline: lang (frontend) → runtime (IR synthesis) → targets.nix (codegen); each layer of the three-layer policy chain holds its own validator — the fleet self-checks against `schema.fleet` (16 keys, class-less), role rows are closed by Law F, and the host layer is open (the only layer without a whitelist), while the loader re-validates the merged result against `schema.shared` (18 keys) and records per-key `why` provenance; deep dive in [mechanisms §0](docs/en/architecture/mechanisms.md) |
| **Layering** | entry / host-dispatch / system / user / shared / secret / test — seven layers with non-overlapping responsibilities; layers communicate through `shared` |
| **Incremental model** | Every subdirectory is an independent module that can be enabled/disabled on its own; the `imports` list is the module registry |
| **Policy management** | `shared.nix` centrally declares every policy option — platform · drive · wm · dm · shell · editor — as a single source of truth |
| **Distribution-layer convergence** | Platform semantics is answered exactly once: the `enum.platform` row carries the `caps` capability vector and the policy payload (home-prefix · btop · trace-tools); the targets classifier, the emitters, and every leaf read the same table (`shared.caps.*` / `shared.platform.value.*`); zero if-else and zero raw-tag comparisons in the config tree (T4.0, borrowed from multi-pass compilers: later passes query the target description and never re-lex) |
| **State machine** | `lib/shared/lang/enum.nix` constrains the set of legal states via `nix-types` enums; illegal values fail at evaluation time |
| **Lifecycle** | Four-stage devShell hooks: `preInputsHook → postInputsHook → preShellHook → postShellHook` |
| **Clear boundaries** | The system layer is unaware of user configuration; the user layer never touches hardware directly; the host layer is the single platform-aware point |
| **Generated files stay generated** | `shared.nix` is generated from a template (overwrite-write) and must not be sed-patched in place; same for `.sops.yaml` |
| **Data-driven** | The secret alias registry is a data file (`secrets/registry.toml`, managed by CRUD verbs); paths originate solely from `shared.nix`; queries go through an sqlite database cache (`secrets/.cache/`, rebuilt automatically on input drift); CI checks are handed over as whole planes (`api.checks.planes`, T7.3) |
| **Communication protocol** | Layers talk through the `shared` attrset (`specialArgs`/`extraSpecialArgs`); `api.inputs` / `api.shared` / `api.targets` / `api.checks.planes` expose flake-side information for scripts and CI to query |
| **Separation of data and interpreter** | Machine facts live in `hosts/` (facter.json hardware data · disk.nix disk layout · persist.nix state policy) while interpretation capability lives in the platform structure tree (nixpkgs facter module · disko registration · impermanence + rollback mechanisms); the host entry does exactly one line of wiring (T5.12/T5.13/T5.14) |

---

## Directory grammar — the distribution layer's grammar

The platform distribution layer (`platform/`) follows the **platform-major · domain-explicit** grammar (v4). One directory per platform tag, with exactly two reserved domain names inside — `system/` and `home/`, each holding its own `default.nix` gate. Read the directory and you know the platform's form; read the path and you know the domain.

```
platform/<tag>/
├── system/               # system domain — only platforms with a system form have one (nixos · darwin · nixos-wsl)
│   ├── default.nix       # system gate: entry and dispatch (subsystem registry + hosts facts)
│   └── core/ dm/ wm/ ... # system config (subdir | file — grows freely)
└── home/                 # user domain — every platform has one
    └── default.nix       # home gate: entry and dispatch (the gate IS the HM payload module)
```

**The six laws of the grammar:**

1. **Two domains, two explicit addresses.** `system/` and `home/` are the only two reserved names under `<tag>/`, each holding a `default.nix` gate — `platform/<tag>/system` and `platform/<tag>/home` are fully symmetric on the two sides of the emitters (in v3 the system domain was an implicit top level and the user domain sat one level lower; v4 gives both domains equally explicit gates — clearer, and more general). File existence = capability declaration (the caps table's projection onto the filesystem): `linux/` and `wsl/` have no `system/` because they have no system form.
2. **One boundary per live gate, and the gate IS the content assembly point.** The system gate = the subsystem registry (`./core ./wm ./dm` + `../../../hosts/<h>` facts); the home gate = the HM entry module itself (base facts + cross-platform user library `../../../home/{core,env,wm}` distribution).
3. **The arch axis is not modeled — natural selection under the dispatch path.** All arches flow through the same pipeline (one stream per platform): arch differences are absorbed at the nixpkgs layer by the emitter's `system` parameter and per-host pkgs synthesis (`runtime.nix` instantiates with `{ system = arch.tag; }`); apps carry their own arch tags, and whether one is enabled is decided automatically once the distribution layer (`lib/shared/`) has finished processing. v3's `home/<arch>.nix` payload row is retired — the target double keeps the platform half as a directory address while the arch half is demoted to a pipeline value.
4. **One path, one meaning.** Zero top-level homonym-with-different-meaning debt; the domain is read from the directory name, not from the hierarchical position (v2 read file names, v3 read hierarchy levels, v4 reads explicit domain directories).
5. **Declared-but-missing paths fail loudly at eval time.** Directory routing is data-driven interpolation (`platform/${shared.platform.tag}/system`); landing on a nonexistent gate errors out immediately.
6. **Dispatch logic lives only in the dispatch layer.** Emitters project the tag from IR (zero if-else, zero raw-tag comparisons — T4.0: later passes query the target description and never re-lex); the config tree is unaware of platform decisions, and subsystem routing is purely data-shaped.

**The five platform forms:**

| Platform | system/ | home/ | Directory form |
| -------- | ------- | ----- | -------- |
| `nixos` | ✅ `default.nix` + `core/ dm/ wm/` | ✅ `default.nix` (the gate IS the payload) | Two gates, two domains, symmetric addresses (policy: standalone HM switches in seconds, rolls back independently of system generations) |
| `darwin` | ✅ `default.nix` (single-gate folding: mounted in HM module mode, the `import ../home` cross-domain reference path stays visible) + `nix/` (nix settings: the fleet-cache pull side, `shared.const` consumed by value) | ✅ (gate IS payload, mounted by the system gate, no independent gate) | Two directories, one live gate |
| `linux` | ✗ | ✅ `default.nix` | home/ is everything |
| `wsl` | ✗ (the Windows host owns the kernel side) | ✅ `default.nix` | home/ is everything |
| `nixos-wsl` | ✅ thin gate: `../../nixos/system` reuse + NixOS-WSL interpreter | ✅ thin gate: `imports = [ ../../nixos/home ]` | Two gates, both thin: read a gate and you know “nixos customs + WSL interpreter” |

**Machine enforcement of the grammar:** `platform-grammar-check` (the fifth repository hygiene gate) asserts the shapes above at build time via a pure `readDir` tree walk — the top of `platform/` allows only platform-tag directories; under `<tag>/` only the two reserved subdomains `system/` + `home/` are allowed (at least one of them); every domain directory must hold a `default.nix` gate matching the regular expression; domain-level payloads allow only module directories (a bare `.nix` file = the corpse class of the v3 arch row; a gate-less directory = invisible to every gate, the reachability gate included). The 82 v3 corpses from run #369 all belong to this defect class — the reachability gate caught them after graph traversal, while the shape gate rejects them directly at the address-space level (zero evaluation cost). When the grammar itself evolves (a new reserved domain), `tests/platform-grammar.nix`'s `reservedDomains` and this section's six laws are updated in the same commit.

**Two shapes of subsystem routing (zero if-else):**

```nix
# single choice (directory interpolation): platform/nixos/system/dm/default.nix
imports = [ ./${shared.display-manager.tag} ];      # ly → ./ly

# multi choice (map routing): platform/nixos/system/core/drive/default.nix
imports = builtins.map (drive: ./${drive}.nix) shared.drive.value;
# shared.drive.value = [ "intel" "nvidia" ] → imports [ ./intel.nix ./nvidia.nix ]
```

---

## Directory structure

Seven top-level layers — one directory per layer, one responsibility per directory (for the **fully annotated tree** — what every single file does — see
[docs/en/architecture/tree.md](docs/en/architecture/tree.md)):

```
nix-config/
├── flake.nix          # entry layer: input declaration + one-line delegation (outputs assembled by the lib/shared/faces.nix link layer, R31)
├── shared.nix         # policy layer (generated by just shared-generate; never hand-edit the username)
├── lib/shared/        # shared layer: lang (frontend) → runtime (IR synthesis) → targets.nix (codegen) → faces.nix (linking)
├── platform/          # distribution layer: platform-major · domain-explicit (five forms: nixos · linux · darwin · wsl · nixos-wsl)
├── home/              # user layer (HM): three domains core / wm / env (no root entry; imported by each platform's home gate)
├── hosts/             # host facts: facter.json · disk.nix · persist.nix + shared.nix overrides
├── secrets/           # SOPS ciphertext (chipr/) + plaintext templates (plan/, never committed)
├── export/            # reusable module outputs (nixosModules · homeModules)
├── overlays/ · pkgs/  # nixpkgs overlay (additions/patches) · custom derivations (wslview shim)
├── tests/             # test layer: 6 planes (smoke/nixos/home/lib/integration/nmt)
├── scripts/           # just submodules (14 verb groups) + sh tools (counting/rotation/export/registry engine)
├── docs/              # deep-dive docs (layered by audience — see the "Deep-dive documentation" index at the end)
└── justfile           # task-automation entry (a bare just prints the start-here map)
```

**Scale facts** (counts are machine-anchored by `tests/docs-ssot.nix`): the `hosts/` directory implements multi-host distribution —
each machine gets independent hardware facts + an optional `shared.nix` override; it currently carries **5 hosts** (nixos · vm · darwin · wsl · nixos-wsl);
flake.nix (47 inputs) — dual-channel nixpkgs (stable + unstable as a second instance), 5 in-house tool
flakes (nix-types · pdshell · configuration-orchestrator · commit-config and the application flakes),
22 external configuration repos (nvim · emacs · wezterm · hypr · waybar ..., flake=false inputs) —
see [docs/en/architecture/dependency-graph.md](docs/en/architecture/dependency-graph.md) for the full dependency graph.

---

## Core mechanisms

Eleven mechanisms, one deep-dive paragraph each ([docs/en/architecture/mechanisms.md](docs/en/architecture/mechanisms.md)):

| # | Mechanism | The essence in one sentence |
| --- | --- | --- |
| 1 | Shared layer · two-stage initialization | `lang` (frontend: types/enums/schema, no pkgs) → `runtime` (IR synthesis: caps/pkgs/i18nScope); scfpath is overridable, so each machine carries its own policy |
| 2 | Policy layer · shared.nix generation | Template + overwrite-write (no in-place sed patching); the single source of truth for policy |
| 3 | Distribution layer · targets.nix | hosts/ inventory → caps classification → four kinds of closure emitters, nixos/darwin/standalone-HM/colmena Hive, + two toplevel projection faces; the link layer faces.nix only `inherit`s finished products, and flake.nix delegates in one line |
| 4 | Dev-environment pipeline · pdshell | A devShell factory with one directory per language; four-stage hooks; combinFrom composition |
| 5 | Security layer · SOPS + Age | TMPL → KEY → RULE → PLAIN → CIPHER → /run/secrets — a six-phase layering |
| 6 | Configuration orchestrator · orc | wallust theme colors injected across applications (activation hook, including waybar theme reload) |
| 7 | User-environment layer · home/env | A directory is an environment domain; one attrset per file (key = shell name) |
| 8 | External configuration repos | flake=false inputs ×22 — dotfiles externalized, revs pinned by flake.lock |
| 9 | Commit discipline | Husky + Commitlint + Commitizen with zero node_modules (commit-config flake) |
| 10 | Multi-host support · hosts/ | Machine facts (facter/disk/persist) separated from the interpreter (the platform structure tree); the host entry is one line of wiring |
| 11 | Services on demand | service-profile: `install` vs `autostart` separation (dev-on-demand / server-pg-only ...) |

---

## Quick start

> For the full six Phases (with per-step prerequisites and caveats) see
> [docs/en/guides/quickstart.md](docs/en/guides/quickstart.md); for the scenario-indexed
> secrets lookup manual see [docs/en/secrets/scenarios.md](docs/en/secrets/scenarios.md).

**Phase 0 — Nix + just ready** (preinstalled on NixOS, skip):

```bash
curl -L https://install.determinate.systems/nix | sh -s -- install   # non-NixOS
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes pipe-operators" >> ~/.config/nix/nix.conf
nix shell nixpkgs#just nixpkgs#git           # not installed globally; one-shot entry
```

> Note: this hand-written `~/.config/nix/nix.conf` line is only a bootstrap bridge — after the first
> home switch it is taken over by `home/core/base/nix.nix` (standalone form, caps-gated:
> experimental-features, the fleet-cache identity, and the user registry all land declaratively;
> see “Architecture overview · three-plane distribution of nix.conf”).

**Phase 1 — Clone + policy & key baseline**:

```bash
git clone https://github.com/Redskaber/nix-config /etc/nix-config && cd /etc/nix-config
just init <username>                         # = policy generation + hardware probing + user age key + .sops.yaml baseline
# server machines with dual keys go direct: just key-new-host <alias> → just init <username> <alias> <age1...>
```

**Phase 2 — secrets ready**:

```bash
nix shell nixpkgs#mkpasswd --command just secret-set-all   # enter item by item (encrypted as you type; plaintext never hits disk)
just secrets-verify                          # recipient-consistency audit (expect all green)
```

**Phase 3 — First deployment**:

```bash
just hosts-list                              # data-driven host inventory (the hosts/ directory)
sudo nixos-install --flake /etc/nix-config#<host>    # A. fresh NixOS (after LiveISO partitioning and mounting)
just nixos-switch <host>                     # B. take over an existing NixOS
just home-switch <host>                      # C. non-NixOS (HM layer); macOS: darwin-rebuild switch --flake .#<host>
```

**Phase 4/5 — Rollback verification and day-2**:

```bash
just nixos-test <host>                       # experimental switch (writes no boot entry; discarded on reboot)
just nixos-boot <host>                       # set only the next-boot generation, no activation
sudo nixos-rebuild rollback                  # one-step rollback to the previous generation
just flake-update-not-sops && just nixos-switch <host>    # routine update (sops-nix stays version-locked)
```

---

## Cross-platform support

| Platform | System layer | User layer | Dev environments |
| ------------ | ------ | ------ | ---------------------- |
| NixOS x86_64 | Full | Full | All (27 devShells) |
| Linux x86_64 | — | Full (+ nixGL) | All |
| macOS ARM64 | nix-darwin closure (build-level acceptance: the CI darwin leg builds on native hardware; activation awaits a real machine) | Full (module mode; lean app-set) | CLI-first |
| WSL2 | NixOS-WSL closure (eval-level acceptance; activation awaits the Windows host) | Full (+ wslview shim, caps.wsl gated in the shared tree) | All (requires systemd enabled) |

---

## Test system

The test suite covers 6 planes, **109 checks = 103 tests + 1 pre-commit-check + 1 docs-ssot-check + 1 testscript-syntax-check + 1 module-reachability-check + 1 platform-grammar-check + 1 cache-ssot-check** in total (counts and TOC navigation are machine-enforced by `tests/docs-ssot.nix` — a count-anchor drift between the README and test-matrix, or a TOC dead link / orphan section, is an immediate CI red light; for a local quick check you can still run `scripts/sh/test-count.sh`, whose output is reconciled against the CI summary):

| Plane | Prefix | Count | KVM | Focus | Typical duration |
| ----------- | -------------- | ------ | -------------- | ------------------------------ | -------- |
| Smoke | `test_` | 1 | QEMU | basic system integrity | ~1 min |
| NixOS | `nixos_` | 30 | QEMU | platform/nixos/* modules + system services | 2–10 min |
| HM | `home_` | 42 | QEMU | home/* package installation + runtime behavior | 2–8 min |
| Lib | `lib_` | 13 | QEMU 256MB min | lib/shared pure Nix expressions (including the orc consumption contract + the include-intent guard contract + the pdshell loader contract + the roles three-layer-chain contract) | <1 min |
| Integration | `integration_` | 1 | QEMU full | NixOS + HM joint activation | 5–15 min |
| **nmt** | `nmt_` | **16** | **✗ zero VM** | HM dotfile content assertions (pure eval) | <10 s |

**nmt-Plane characteristics:** pure Nix eval, no QEMU, no KVM; it uses `scrubDerivations` to replace packages with `@pkg-name@` placeholders so no real builds are triggered (everything outside the whitelist is scrubbed). It is the fastest feedback path in CI.

**nmt vs HM-Plane complementarity:**

```
home/core/exp/sys/base/fd.nix
  ├─ nmt_home_core_exp_sys_base_fd     dotfile content assertions (pure eval, <10s)
  │    tests/nmt/home/core/exp/sys/base/fd.nix
  │    .config/fd/ignore: .git/ / *.bak entries
  └─ home_core_exp_sys_base_fd          runtime behavior (QEMU VM, ~2min)
       tests/home/core/exp/sys/base/fd.nix
       fd --version, fd finds files by pattern
```

**CI whole-plane handoff (no manually maintained lists):**

```bash
# plane membership is declared by the planes face in tests/default.nix — a new test lands in its plane by construction;
# CI hands the whole plane to nix-fast-build (resolved from locked nixpkgs — zero registry drift):
nix-fast-build --no-nom --skip-cached -j "$(nproc)" \
  --flake ".#api.checks.planes.nixos"

# plane groups are independently addressable (derivation attrsets shaped like .#checks.<system>):
nix eval ".#api.checks.planes.nmt" --apply builtins.attrNames --json
```

**Run commands:**

```bash
# full run (needs KVM; deep eval can also run --no-build without KVM)
nix flake check

# nmt only (fastest, no QEMU)
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" --no-link

# single test
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_git -L
nix build .#checks.x86_64-linux.nixos_core_srv_db_postgresql -L
nix build .#checks.x86_64-linux.integration_hm_activation -L

# export/ module-doc regeneration (docs.nix side-channel emitter)
nix build .#module-docs    # → result/options/{home-,nixos-}<module>.md + index
```

**nmt acquisition mechanism:** sourcehut returns HTTP 403 to Nix fetcher UAs, so this repo uses `github:Redskaber/nmt` (a mirror) with `flake = false`, referenced directly by store path. The `buildHomeManagerTest` wrapper is implemented in-house in `tests/nmt/default.nix` (upstream nmt does not provide this function).

See also [`docs/en/tests/test-matrix.md`](docs/en/tests/test-matrix.md) · [`docs/en/tests/nixosTest.md`](docs/en/tests/nixosTest.md) · [`docs/en/tests/nmt.md`](docs/en/tests/nmt.md)

---

## CI/CD complete execution flow

### Why a Nix configuration needs CI/CD

Every change to nix-config is equivalent to declaring a new system state. The core value of CI:

1. **Evaluation check** — catches Nix syntax/type errors (earlier than a failing nixos-rebuild)
2. **Deep evaluation** — face-sharded enforcement: the api envelope + per-host toplevel drvPath + misc checks + completeness reconciliation (all 109 checks must be owned by a plane or by the misc list; the single-process `nix flake check` has been retired because of its memory-accumulation floor)
3. **Secret integrity** — verifies the encrypted-file structure is correct and `secrets/plan/` has not been committed
4. **Test coverage** — 103 tests covering the nixos/home/lib/integration/nmt planes
5. **Automatic updates** — every Sunday, flake inputs are auto-updated and a PR opened

### The actual pipeline (10 stages, maximum parallelism)

```
push / PR
    │
    ├─► [STAGE 1: Lint & Evaluate]        static analysis + shallow eval (< 2 min)
    │       ├── nix eval .#formatter.*.name               (formatter evaluable)
    │       ├── nix eval .#devShells.* attrNames          (devShells non-empty)
    │       ├── nix eval .#nixosConfigurations attrNames  (structure verification)
    │       ├── nix eval .#homeConfigurations attrNames
    │       ├── nix eval .#checks.* attrNames + plane counts
    │       ├── statix check .                            (Nix anti-pattern check)
    │       ├── nixfmt check / deadnix check
    │       ├── Build pre-commit-check derivation
    │       └── Build docs-ssot-check derivation          (doc count anchors)
    │           + Build testscript-syntax / module-reachability /
    │             platform-grammar / cache-ssot derivations
    │
    ├─► [STAGE 2: Deep Evaluation]       deep evaluation (hard gate, face-sharded)
    │       └── face-sharded enforcement: api envelope + per-host toplevel drvPath
    │           + misc checks (docs-ssot/pre-commit) + completeness reconciliation
    │           (all 109 checks must be owned by a plane or the misc list — a new
    │           test file that never registers a plane goes red; short-lived
    │           processes replace the single-process flake check: memory safety
    │           + wall clock 120m → est. 15-25m; pure-eval: no magic-nix-cache, infra-signed retry)
    │
    ├─► [STAGE 3: nmt-Plane]           HM dotfile assertions, pure eval, no KVM (< 1 min)
    │       └── nix-fast-build --flake .#api.checks.planes.nmt (parallel eval + build)
    │
    ├─► [STAGE 4: devShells dry-run]   per-member dry-run (face attrNames)
    │       └── enumeration = the devShells face's own attrNames (27 members named;
    │           new shells join by construction, zero CI upkeep; failures named for attribution)
    │
    ├─► [STAGE 4.5: Output Faces]     drvPath enforcement for faces with no dedicated leg (parallel)
    │       ├── packages.* per-member drvPath (the wslview lesson — deep-eval's
    │       │   face coverage is path-dependent: an early red hides later breakage; failures named)
    │       ├── homeConfigurations.* activationPackage.drvPath
    │       │   (home-plane tests are nixosTest VMs; they never touch this face)
    │       └── darwinConfigurations.* system.drvPath (host-toplevels'
    │           darwin eval step runs after deep-eval goes green; this leg is exempt)
    │
    ├─► [STAGE 5: Security Audit]      SOPS integrity audit (parallel)
    │       ├── supply-chain pinning contract: every action ref must be a 40-hex SHA (fail-fast)
    │       ├── secrets/chipr/*.yaml must carry sops: metadata
    │       ├── secrets/plan/ must not be tracked by git
    │       ├── .sops.yaml carries age: + creation_rules:
    │       └── .nix files scanned for hardcoded token/password
    │
    ├─► [STAGE 6: VM Tests]            QEMU tests, per-plane parallel sub-matrices (KVM required)
    │       ├── one plane per leg, whole face handed to nix-fast-build (nix-eval-jobs
    │       │   parallel eval + pipelined builds; --skip-cached meets magic-nix-cache):
    │       ├── smoke        — baseline (1)
    │       ├── nixos        — system modules (30)
    │       ├── home         — HM modules (42)
    │       ├── lib          — lib pure expressions (12)
    │       └── integration  — NixOS + HM joint activation (1)
    │
    ├─► [STAGE 6.5: Host Toplevels]   system-closure builds (no KVM)
    │       ├── .#api.host-toplevels — the whole face goes to nix-fast-build
    │       │   (inventory-driven: nixos · vm · nixos-wsl — new NixOS hosts join by
    │       │   construction; cache.nixos.org substitute + magic-nix-cache cross-run caching)
    │       └── darwin closure cross-system eval step (a zero-cost cross-check on
    │           the linux leg; build depth belongs to the 6.6 leg)
    │
    ├─► [STAGE 6.6: Darwin Toplevels]  darwin closure native builds (macos-latest
    │       │   aarch64 runner, no cross toolchain needed: the api.darwin-toplevels
    │       │   sixth api face handed whole to nix-fast-build — same tools, same
    │       │   discipline, inventory-driven; new darwin hosts join by construction)
    │
    └─► [STAGE 7: Summary]             summary report (always, even after earlier failures)
```

**Local pre-flight checklist (before push) · deployment workflows · generation-management details · automated-update strategy**
→ [docs/en/ci/pipeline.md](docs/en/ci/pipeline.md).

---

## Daily operations quick reference

> The full verb face carries 98 recipes, annotated `[group]` into 14 groups — run `just --list` in a terminal, or see
> [docs/en/just/reference.md](docs/en/just/reference.md); a bare `just` prints the start-here map.

### deploy — the deployment verbs (the three nixos-rebuild semantics + HM + the colmena remote face)

```bash
just nixos-switch <host>       # = sudo nixos-rebuild switch --flake .#<host> (activation)
just nixos-test <host>         # test: experimental switch, discarded on reboot
just nixos-boot <host>         # boot: set only the next-boot generation, no activation
just home-switch <host>        # standalone HM (→ <username>@<host>)
just hosts-list                # host inventory (hosts/ directory, data-driven)

just deploy-list               # colmena deployment face (= nixosHosts)
just deploy <host>             # colmena remote deployment: build → upload → activate (ssh, policy user)
just deploy-local              # colmena local deployment (apply-local --sudo)
```

### Development environments — devShells and profiles

**Available devShells quick reference (27 of them, `nix eval .#devShells.x86_64-linux --apply builtins.attrNames`):**

| Shell name                     | Compositional contents                              | Traits                          |
| ------------------------------ | ------------------------------------- | ----------------------------- |
| `rust`                         | rustc + cargo + rust-analyzer         | clippy · rustfmt              |
| `go`                           | go + gopls + delve                    | China mirrors · project-level cache         |
| `python`                       | python314 + uv + pyright              | ruff · bytecode-cache isolation      |
| `python-machine`               | C + Python + gcc.cc.lib               | ML/DL toolchain · GPU guidance       |
| `python-renpy`                 | python314 + renpy + unrpyc            | Visual Novel development             |
| `cpp`                          | pure LLVM (libc++ + clangd)           | lld · lldb · bear · ccache    |
| `c`                            | clang + clangd + lld                  | bear · ccache · cmake · ninja |
| `asm`                          | nasm + binutils                      | assembly                          |
| `java`                         | temurin-21 + maven + jdt-ls           | gradle                        |
| `typescript`                   | node26 + tsc + tsx                    | typescript-language-server    |
| `javascript`                   | node26 + biome                        | pnpm · yarn                   |
| `nix`                          | nix + nil + statix + nixfmt           | deadnix · nvd                 |
| `nix-derivation-free`          | + nix-output-monitor + nixpkgs-review | PR-review workflow                 |
| `nix-derivation-unfree`        | + patchelf + sbomnix + gpg            | closed-source builds · compliance           |
| `nix-derivation-free-security` | + vulnix                              | security scanning                      |
| `nix-nonfmt`                   | a bare nix shell with no formatter interference        | script writing                      |
| `re`                           | LLVM + a full reverse-engineering toolchain                 | pwntools · frida · ghidra     |
| `lua`                          | lua54 + luajit + lua-language-server  | stylua · luarocks             |
| `lisp`                         | sbcl + rlwrap                         | pkg-config · gcc              |
| `zig`                          | zig + zls                             |                               |
| `haskell`                      | ghc910 + cabal-install + HLS          | fourmolu · hlint · hoogle      |
| `ocaml`                        | ocaml 5 + dune_3 + ocaml-lsp          | ocamlformat · utop · merlin    |
| `default`                      | combinFrom merge of all languages                | the general-purpose dev environment                  |
| `cpython`                      | C + C++ + Python combo                 |                               |
| `godot`                        | C + C++ + Python + godot              | game development                      |
| `makeOs`                       | asm + c + qemu_full + just            | an OS experimentation environment                   |
| `rs_compiler_dev`              | rust + a compiler-theory toolchain                  | rs development                       |

```bash
# one-shot entry (no profile saved)
nix develop .#rust · .#python · .#python-machine ...
# persistent profiles (usable offline; named <username>-<lang>[-<class>], land in ~/.local/state/nix/profiles/dev/)
just devenv-create rust                        # single language
just devenv-create-from python machine         # composite variant (C + Python ML/DL)
just devenv-use [-from] <lang> [<class>]       # enter an existing one
# direnv auto-activation (recommended)
echo "use flake github:Redskaber/nix-config#python-machine" > .envrc && direnv allow
```

### secrets — a quick-reference table (one command per intent)

| Intent | Command |
| --- | --- |
| What encrypted content do I have / what is missing | `just secrets-list` |
| Register a new secret (all three layers written at once) | `just secrets-add <alias> <rel-path> [prompt]` |
| Change a registry row's prompt / transform | `just secrets-edit <alias> [prompt] [transform]` |
| Retire a secret (destroy the ciphertext first) | `just secrets-remove <alias>` |
| One secret's full dossier (without decrypting) | `just secrets-show <alias>` |
| Declaration ↔ registry drift view | `just secrets-declared` |
| Registry cache status | `just secrets-db` |
| Enter / change one secret | `just secret-set <alias>` |
| Read one secret | `just secret-get <alias>` |
| Edit one secret | `just secret-edit <alias>` |
| Enter all of them, in order | `just secret-set-all` |
| Who can decrypt (key/rule overview) | `just secrets-status` |
| Rules ↔ ciphertext consistency | `just secrets-verify` |
| Re-align ciphertext after rules change | `just secrets-sync` |
| The lifecycle map | `just secrets-guide` |

> The layer model in one line: TMPL → KEY → RULE → PLAIN → CIPHER → `/run/secrets/`;
> the entry point is `just secrets-guide` (state machine + verb matrix + scenario flows).
> The nine-scenario manual (day-one / dual keys / onboarding a server / a second machine / bidirectional rotation / compromise response /
> additions / destruction): [docs/en/secrets/scenarios.md](docs/en/secrets/scenarios.md);
> the rotation runbook: [docs/en/secrets/rotation.md](docs/en/secrets/rotation.md).

### Generations and rollback

```bash
sudo nixos-rebuild rollback                                                   # roll back to the previous generation
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation <N>   # switch to a specific generation
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

---

## Known boundaries and design debt

Everything machine-assertable is already carried by the six repository hygiene gates; this table is the ledger of residual boundaries the gates cannot reach —
items that need real hardware, an owner decision, or external collaboration, tracked explicitly so they cannot silently evaporate
(exempt-class entries additionally have a STALE-red tripwire backstop inside the corresponding gate).

| # | Boundary / debt | Current state | Owner |
| --- | --- | --- | --- |
| 1 | darwin activation awaits a real Mac | the aarch64 closure is already CI-built on native hardware (macos-latest); activation and switching semantics are not yet accepted on a real machine | real hardware |
| 2 | hosts/nixos facter migration | the repo side has fully landed (`just hardware-migrate` four steps + the targets three-law tests); root probing is gated on real-hardware execution | real hardware |
| 3 | cachix push step awaiting activation | pushing the closure is proven (wechat 762 MB); the CI push step activates once the secret is injected | owner |
| 4 | sound adjudication on real hardware | the policy axis has landed (pipewire default + the none enum + the two-law lock); flipping the console host awaits a real-machine listening test | real hardware |
| 5 | a second machine + ssh public key | the colmena remote face and the deployment equivalence gate are ready; the base-policy openssh-authKeys is still empty | hardware |

---

## Roadmap

- [x] CI full-build verification (nmt-Plane + QEMU VM tests, a 7-stage pipeline)
- [x] NixOS test suite (91 checks = 90 tests + 1 pre-commit-check [which bundles the three nixfmt/statix/deadnix hooks], 6 test planes)
- [x] flake inputs auto-update policy (scheduled PR, every Sunday)
- [x] platform/ platform distribution layer (nixos · linux · darwin · wsl, arch routing)
- [x] api.inputs exposure (just scripts dynamically enumerate inputs, zero hardcoding)
- [x] AI CLI tool integration (claude-code · opencode · gemini-cli · kiro-cli · cursor-cli · pi-coding-agent)
- [x] kiro editor integration (home/core/exp/app/editor/kiro.nix)
- [x] nmt mirror solution (sourcehut 403 workaround, buildHomeManagerTest self-implemented)
- [x] sops data-driven architecture (zero hardcoded paths, phase-aware source separation)
- [x] secrets just lifecycle redesign
- [x] tools.nix unified tool management (nix-types / orc / pdshell short-path access)
- [x] hosts/ multi-host support (per-machine facts + overrides; facter/disko declarative form)
- [x] service-profile on-demand starting (install vs autostart separation, dev-on-demand / full-autostart / server-pg-only / minimal)
- [x] editor-set / terminal-set / browser-set collection routing (a multi-select routing mode)
- [x] version policy carrying (variant carries {stateVersion, wine, swww} policies)
- [x] shellIntegrations unification (computed at runtime, reused by 8 base modules)
- [x] match exhaustiveness
- [x] distribution-layer convergence
- [x] entry-point slimming
- [x] middle-layer naming convergence
- [x] pre-commit-hooks (nixfmt + statix + deadnix auto checks)
- [x] services.just on-demand start commands (service-start/stop/status + db-start/stop/list)
- [x] lazy module loading
- [x] module doc auto-generation
- [x] darwin platform dispatch mechanism unification
- [x] darwin emitter assembly cohesion
- [x] platform architecture complete
- [x] darwin single-gate folding
- [x] export/ module polish
- [x] policy-table completion
- [x] CI build depth
- [x] docs-SSOT count contract
- [x] CI host-closure build leg
- [x] CI darwin-closure build leg
- [x] nixos-facter replaces nixos-generate-config (declarative hardware discovery)
- [x] disko declarative disk partitioning (replacing the hardcoded fileSystems in hardware.nix)
- [x] Option/Result typed error handling
- [x] Observability (prometheus exporters + loki logs + grafana dashboard)
- [x] Health checks (systemd HealthCheck for database services)
- [x] tree hygiene
- [x] impermanence (experimental)
- [x] NixOS-WSL as the fifth system form
- [x] output-faces independent enforcement leg
- [x] CI pure-eval leg infrastructure decoupling
- [x] CI deep-eval face sharding
- [x] supply-chain actions SHA pinning
- [x] sound semantic-half adjudication dossier
- [x] devShells-leg member enumeration data-driven
- [x] hosts/nixos facter migration, repo side fully landed
- [x] colmena deployment face landed
- [x] pipeline reference cards & peer comparison on record (pipeline.md · comparison.md zh+en, R9)
- [x] object-structure view & four-emitter alignment (six files zh+en, 14 fixes, R10)
- [x] cross-cutting dimensions on record & overview sync check (pipeline.md §4 deps/secrets/UX/external-configs × zh+en, R11)

---

## Deep-dive documentation

Deep-dive content is layered by audience into `docs/` — the README keeps only the entry layer; this section is the full index:

| Audience | Document | Content |
| --- | --- | --- |
| Architecture understanding | [architecture/mechanisms.md](docs/en/architecture/mechanisms.md) | The internals of the eleven core mechanisms |
| Pipeline reference | [architecture/pipeline.md](docs/en/architecture/pipeline.md) | Compiler-pipeline pass cards · layer×stage bridge · cross-cutting dimensions (deps/secrets/UX/external configs) · invariants |
| Peer comparison | [architecture/comparison.md](docs/en/architecture/comparison.md) | 16-dimension peer scoring snapshot · cross-learning checklist |
| | [architecture/tree.md](docs/en/architecture/tree.md) | The fully annotated tree |
| | [architecture/dependency-graph.md](docs/en/architecture/dependency-graph.md) | The 47-input dependency graph |
| | [architecture/external-repos.md](docs/en/architecture/external-repos.md) | External repos, layered and classified (four roles × four repos) |
| | [architecture/nix-types.md](docs/en/architecture/nix-types.md) | The type-system integration adjudication |
| CI/CD | [ci/pipeline.md](docs/en/ci/pipeline.md) | Origins, local pre-flight, and the deployment flow |
| Getting started | [guides/quickstart.md](docs/en/guides/quickstart.md) | Six Phases from zero to deployed |
| | [guides/extending.md](docs/en/guides/extending.md) | Adding apps / language environments / secrets / policies |
| | [guides/cache.md](docs/en/guides/cache.md) | Local cache pulling and pushing |
| Adjudication dossier | [guides/sound-adjudication.md](docs/en/guides/sound-adjudication.md) | The semantic half of sound (debt #9) |
| Daily operations | [just/reference.md](docs/en/just/reference.md) | The full 98 recipes × 14 groups reference |
| Module development | [modules/interface-standards.md](docs/modules/interface-standards.md) | Module interface standards (refactoring is wiring) |
| secrets | [secrets/scenarios.md](docs/en/secrets/scenarios.md) | The nine-scenario manual |
| | [secrets/rotation.md](docs/en/secrets/rotation.md) | Key hierarchy and the rotation runbook |
| Testing | [tests/test-matrix.md](docs/en/tests/test-matrix.md) | The test matrix (six-plane counts) |
| | [tests/nixosTest.md](docs/en/tests/nixosTest.md) | The complete NixOS-test manual |
| | [tests/nmt.md](docs/en/tests/nmt.md) | The complete guide to the NMT mirror solution |
