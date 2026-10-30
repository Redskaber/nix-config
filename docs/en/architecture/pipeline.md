# Compiler Pipeline & Layered Architecture — Full Reference

> This doc is the **canonical reference** for pipeline content: pass-by-pass
> reference cards, the layer-map × pipeline-stage bridge, the cross-cutting
> dimensions (dependencies × secrets × user interaction × external configs),
> the naming-model index, design invariants, and change
> playbooks. The overview diagram lives in the
> [README architecture overview](../../../README.en.md#architecture-overview);
> per-segment prose lives in [mechanisms.md](mechanisms.md) (§0 overview,
> §1–§3 the per-stage deep dives, §4–§11 the cross-cutting mechanisms).
> Division of labor: README for the quick view,
> mechanisms for the "why", this doc for "one page to check everything".

## 1. Pipeline Map (seven one-way stages)

The repo models itself as a compiler: policy files are source code, flake
outputs are object code, `specialArgs` is the ABI. The whole pipeline flows
one way, with no reverse dependencies:

```
source    shared.nix (fleet layer) · enum.nix role table (role layer)
          · hosts/<h>/shared.nix (host layer, optional open file)
            ↓
Pass 1    lib/shared/lang/          front-end: types · enums · schema ·
(front-end)                          validation (pure Nix, zero pkgs)
            ↓
Pass 2    lib/shared/default.nix    middle-end: three-layer controlled
(merge)                              merge fleet ⊕ role ⊕ host (Law F
                                     whitelist · schema.shared 18-key
                                     re-validation · hostName force-
                                     alignment · per-key why provenance)
            ↓
Pass 3    lib/shared/runtime/       IR synthesis: caps · pkgs/upkgs ·
(synthesis)                          i18nScope · homeDir · orc · pdshell ·
                                     three sops path functions · set
                                     flattening (editors/terminals/
                                     browsers/appCategories/services)
            ↓
Pass 4    lib/shared/targets.nix    backend: readDir hosts/ inventory →
(codegen)                            caps table classification → four
                                     emitters (nixos / darwin /
                                     standalone-HM / colmena Hive) + two
                                     toplevel projection faces
            ↓
Pass 5    lib/shared/faces.nix      link: artifacts assembled onto flake
(link)                               protocol output names (flake.nix keeps
                                     only input registration + one
                                     delegation line)
            ↓
Pass 6    specialArgs /             load: platform/ · home/ module trees
(load)    extraSpecialArgs          consume the handle via
                                     { shared, inputs, ... }
```

**Compiler metaphor mapping:**

| Compiler concept | This repo's counterpart |
| ---------------- | ----------------------- |
| Front-end (lexing/parsing/semantic checks) | `lib/shared/lang/`: enum construction is exhaustive-by-construction, schema destructuring validators, the validate Result railway |
| Middle-end (IR + optimization passes) | three-layer controlled merge + `runtime/` handle synthesis; optimizations like CSE (`sharedByHost` single instantiation per host) |
| Backend (object-code generation) | the `targets.nix` four emitters: generate nixos / darwin / standalone-HM / colmena Hive closures per target description (one policy graph in, four closure formats out) |
| Target description (target triple) | the caps capability vector of `enum.platform` rows — later passes query the table, never re-lex the target |
| Linker (symbol assembly) | `faces.nix`: six-gate checks aggregation / module-docs / pdsh / tests single construction |
| Symbol table | the output naming model (Law G) — directory names per-kind unique, see §5 |

**Object-structure view (assembly relations, orthogonal to the map above):**
read the map above by **evaluation order** — how data flows; read the one
below by **ownership** — who assembles whom. The two are projections of one
pipeline: pass 5 link = the faces.nix box, pass 4 codegen = the targets.nix
box + classifier + four emitters, pass 6 load = everything below
modules/specialArgs; `flake.lock` is the first fact source of evaluation
(the locked input graph decides every upstream rev):

```
flake.lock ─▶ flake.nix (input registration + one-line delegation) ─▶ faces.nix
                               │
              ┌────────────────▼────────────────────────────┐
              │ targets.nix — the backend factory           │
              │  shared = import ./default.nix (base)       │
              │  · the merge itself happens in default.nix: │
              │    fleet ⊕ role ⊕ host override             │
              │  sharedByHost = genAttrs hostNames mkShared │
              │    (lazy: unforced hosts cost nothing)      │
              └───────┬──────────────────────┬──────────────┘
   caps table lookup  │                      │ per-host IR handle
   (zero if-else)     │                      │ sharedByHost.<h>
              ┌───────▼────────┐     ┌───────▼──────────────┐
              │ classifier     │     │ per-host IR          │
              │ nixosHosts     │     │ (CSE: one instance   │
              │ darwinHosts    │     │ per host; base entry │
              │ standaloneHosts│     │ IS the base handle)  │
              └───────┬────────┘     └───────┬──────────────┘
              ┌───────▼──────────────────────▼──────────┐
              │ four emitters — one policy graph in,    │
              │ four closure formats out                │
              │ nixosSystem · darwinSystem · homeManager│
              │ colmena Hive (nodeSpecialArgs hands the │
              │ same per-host thunks — re-emission      │
              │ isomorphic)                             │
              └───────────────┬─────────────────────────┘
   modules = [ platform/${tag}/system|home ] + specialArgs { inputs, shared }  (the ABI)
                              │
              ┌───────────────▼─────────────────┐
              │ platform doors (capability      │
              │ declaration: file presence IS   │──▶ hosts/<h> facts
              │ the declaration)                │   (hardware·disk·persist
              │  platform/<tag>/system (system  │    mounted by the system
              │  door)                          │    door; deploy.nix feeds
              │  platform/<tag>/home (home door,│    the colmena emitter)
              │  the door IS the payload)       │
              └───────────────┬─────────────────┘
                              ▼
   home/{core,env,wm} leaves — directory-interpolation routing ·
   mkIf caps gating · strategy payload .value.* · sops Result
   railway · externalized dotfiles · orc activation
   (deep dives per mechanism: mechanisms.md §2 · §5 · §6 · §8)
```

## 2. Pass Reference Cards

One card per stage: location, consumes → produces, guard (which test/gate
pins it), failure mode (when, at which layer, how loud).

| # | Pass | Location | Consumes → Produces | Guard | Failure mode |
| - | ---- | -------- | ------------------- | ----- | ------------ |
| 0 | source (three-layer policy chain) | `shared.nix` · `enum.nix` role table · `hosts/<h>/shared.nix` | — → fleet baseline (identity / majority defaults / roles registry) + role form bundles + host class keys & specialisation | Law E (`tests/lib/shared/roles.nix`: registry ↔ hosts/ zero drift, both directions); `shared-roundtrip` (template ↔ generated byte-identical) | unregistered host directory → loader throws "no role assignment"; template/generated drift → roundtrip gate red |
| 1 | front-end | `lib/shared/lang/` | source policy → type system (17 enum tables + schema destructuring validators + validate Result railway), zero pkgs | `lib_shared_lang_*` 7 tests (enum/caps/schema/fn/validate/version); nix-types version pin (`lib_shared_lang_version`) | out-of-range/duplicate enum construction → throws at construction; missing branch in exhaustive dispatch → match throws |
| 2 | middle-end (merge) | `lib/shared/default.nix` | fleet ⊕ role ⊕ host → controlled merge result + per-key `why` provenance | Law F: out-of-whitelist keys in a role row (identity/class keys) → throw at the single merge point, offending keys named; `schema.shared` 18-key contract re-validation (`lib_shared_lang_schema` statically pins functionArgs) | a role row carrying `user`/`platform` → throw listing every offending key; merged result missing a key → schema destructuring eval failure |
| 3 | IR synthesis | `lib/shared/runtime/` | merge result → handle: caps resolution · pkgs/upkgs dual instances · i18nScope · homeDir · orc/pdshell · three sops path functions · five set flattenings | `lib_shared_lang_validate` (secret-path Result railway: declared-but-not-provided surfaces at eval); i18n dual-source mixing `fn.sameSource` eval-time throw | stable/unstable mixed input-method stack → loud eval failure (structural immunity to the 995d8c9 incident); declared secret without blob → eval-time trace of bootstrap commands (turns strict once a blob exists) |
| 4 | backend (codegen) | `lib/shared/targets.nix` | handle × hosts/ inventory → `nixosConfigurations` / `homeConfigurations` / `darwinConfigurations` / `colmenaHive` + `hostToplevels` / `darwinToplevels` projections | Law G: legacy alias `<user>-<platform>` shadowing a real host directory → eval throw; `lib_shared_targets` naming census (three faces' keys exactly equal the inventory · no face name carries an arch tag · hostName aligned per host) + fact census (Laws A/B/C); `lib_shared_deploy` (colmena emission coverage = nixosHosts, version identity single-sourced) | alias collision → throw (a lying name, the worst failure mode — compiler same-scope redeclaration semantics); deploy.nix on a non-NixOS host → throw "lying file" |
| 5 | link | `lib/shared/faces.nix` | producer artifacts → flake protocol output names (six-gate checks aggregation / api faces / devShells / packages / formatter / export modules) | `lib_shared_deploy` (asserts the verbatim argument record faces.nix consumes); docs-ssot (pdsh count = devShells face) | the link layer only writes `inherit` — no independent failure mode here; upstream throws pass through unchanged |
| 6 | load | `specialArgs` / `extraSpecialArgs` → `platform/<tag>/{system,home}` | output faces → module-tree evaluation (consuming `{ shared, inputs, ... }`) | module-reachability gate (every default.nix directory under home/ + platform/ reachable from 9 graph roots); platform-grammar gate (directory grammar v4 shape) | dangling module directory → reachability gate red; v3-corpse shape → grammar gate red (rejected at the address-space layer) |

**Cross-pass invariants:** single instantiation of the per-host policy IR
(the `sharedByHost` table — classifier/emitters/naming/alias all read one
table; the default host's entry IS the base instance's shared handle);
under lazy evaluation unforced host closures cost nothing; `//` merges are
never deep (enum instances are attrsets — a deep merge would corrupt their
strategy payloads).

## 3. Layered Architecture × Pipeline Stages

The bridge table between the repo's seven structural layers and the compiler
stages — "layers" are **disk organization** (responsibility boundaries),
"passes" are **evaluation-time order** (data flow); the two are orthogonal:
the shared layer hosts passes 1–5, the test layer cuts across all passes,
the secret layer cuts across pass 6's runtime.

| Repo layer | Directory | Pipeline role | Key constraint (guard) |
| ---------- | --------- | ------------- | ---------------------- |
| entry | `flake.nix` | input registration + one delegation line (pass 5's artifacts surface here) | zero cache identity at the entry layer (cache-ssot three-prohibition assertion: identifier/URL/public key) |
| shared | `lib/shared/` | where passes 1–5 all happen (lang → default → runtime → targets → faces) | two-phase initialization (lang zero pkgs → runtime injection); per-host single instantiation |
| host-dispatch | `platform/<tag>/` | pass 6's facade: the platform directory is the platform half of the target double (the arch half is a pipeline value) | directory grammar v4 (platform-grammar gate); file presence = capability declaration |
| system | `platform/<tag>/system/` | system-domain module tree (core/dm/wm/...; only nixos · darwin · nixos-wsl have one) | system/default.nix = the system door: entry + hosts facts mounting |
| user | `home/` + `platform/<tag>/home/` | user-domain module tree (core/exp/sec/srv + env + wm) | home/default.nix = the home door, the door IS the payload, arch axis retired |
| secret | `secrets/` + `.sops.yaml` | cuts across pass 6's runtime (initrd decryption → /run/secrets) | plaintext never committed (CI secret-integrity stage); lenient at eval, hard-fail at deploy |
| test | `tests/` | cuts across all passes (6 planes, 108 tests + 6 repo-hygiene gates = 114 checks) | count anchors machine-enforced by docs-ssot; new tests travel with their anchors in the same commit |

The seven structural layers answer "who lives where on disk"; four more
dimensions are **not disk layers but orthogonal axes cutting across them** —
dependencies, secrets, user interaction, external configs — how each flows
through the same passes is the next section.

## 4. Cross-Cutting Dimensions × Pipeline Stages (deps · secrets · UX · external configs)

### 4.1 Dependency layering — the 47 inputs' four classes × pass-consumption matrix

`flake.lock` is the first fact source of evaluation (the object-structure
view, §1). The 47 inputs (counting basis = the evaluated face's `attrNames`;
the grep-`.url =` figure of 46 never enters docs) fall into four classes:
community upstream 14 · own tool libraries 4 · own app flakes 6 · own
non-flake sources 23. Which pass consumes which inputs — one matrix:

| Pass | Inputs consumed | Role |
| ---- | -------------- | ---- |
| 1 front-end | **nix-types** (version pin: `lib_shared_lang_version`) | the type foundation — enum/match/Option/Result; zero pkgs is its qualification for Phase 1 |
| 3 synthesis | **pdshell** (devShell-pipeline handle) · **orc** (config-tree orchestration handle, resolved per arch) | runtime injects the `shared.pdshell` / `shared.orc` short paths |
| 4 codegen | nixpkgs · nix-darwin · home-manager · colmena | the four emitters' engines (nixosSystem / darwinSystem / homeManagerConfiguration / makeHive) |
| 5 link | pre-commit-hooks (pre-commit-check) · pdshells → devShells face | checks-gate aggregation + the devShell face |
| 6 load | sops-nix · disko · impermanence · nixos-wsl (interpreters, one import line each, registered platform-side) · nixgl · nur · hyprland(+plugins) | system-domain interpreters and payloads |
| tests (vertical) | **nmt** (plane 5, flake=false) | the HM module-test framework |
| payload (horizontal) | own app flakes 6 (wechat · cnmplayer · unrpyc · trae · z-library · zcode) | consumed by reference from home/env |

The four own repos distribute orthogonally by pipeline phase — no cycles, no
substitutability, only top-down one-way consumption: nix-types (phase-1
front-end) → pdshell / orc (runtime synthesis) → pdshells (faces emission) →
nmt (tests exclusive). The full layering facts and shared contracts live in
[external-repos.md](external-repos.md); the per-repo dependency tree in
[dependency-graph.md](dependency-graph.md).

### 4.2 Security secrets — the six-phase lifecycle × pass mapping

A secret is not a static layer of files but a cross-pass **declare → validate
→ decrypt → mount** pipeline:

```
TMPL (docs/tmpl/sops/ templates)
  → KEY (age keys, grouped per consumer)
  → RULE (.sops.yaml creation rules: path → key group)
  → PLAIN (generated by secrets-init; plaintext never committed — CI secret-integrity stage)
  → CIPHER (sops encrypt — the only form inside git)
  → /run/secrets/ (sops-nix runtime decryption & mount, initrd stage)
```

| Pass | Secret action | Guard |
| ---- | ------------- | ----- |
| 0 source | the `secrets` key of `shared.nix` declares the inventory | schema.secrets sub-validator (lambda presence contract) |
| 3 synthesis | sopsFile / sopsPath / sopsUserPath synthesized — the **Result railway**: declared-but-no-blob → eval-time trace of bootstrap commands (turns strict once a blob exists) | `lib_shared_lang_validate` |
| 6 load | sops-nix interpreter registered (one import line, platform-side) → initrd decryption → /run/secrets | plaintext never committed (CI); lenient at eval, hard-fail at deploy |

(Passes 1–2 and 4–5 never touch secrets: type checks, merging, closure
assembly, and linking are all zero-key.) Deep dive:
[mechanisms.md §5](mechanisms.md#5-security-layer--sops--age-layered-management);
the scenario-based handbook in [secrets/scenarios.md](../secrets/scenarios.md).

### 4.3 User interaction — user-facing planes × pipeline paths

"Everything the user touches" is policy-driven and flows through the same
pipeline:

| User plane | Carrier | Pipeline path |
| --------- | ------- | ------------- |
| Login shell & global tools | `home/env/base` (clang · rustc · python · node · valgrind... always available, no devShell needed) | pass-3 handle → pass-6 home door |
| Per-language devShells | `home/env/dev/<lang>/` (one attrset per file, key = shell name) → pdshell → devShells face | pass-3 handle → pass-5 face (`nix develop` / `just devenv-*`) |
| Window managers | `home/wm` (gnome · hyprland · niri · none; the `window-manager` enum row carries the portal policy) | pass-1 enum → pass-6 mkIf caps gating |
| Theming (wallust cross-app injection) | orc activation hook (incl. waybar theme reload) | pass-3 `shared.orc` → pass-6 activation |
| AI CLI tools | `home/core/exp/sys/ai/` (claude-code · opencode · gemini-cli · kiro-cli · cursor-cli · pi-coding-agent) | pass-6 user-domain module tree |
| App sets | editors / terminals / browsers / appCategories flattening | pass-3 five-set flattening → pass-6 leaves |

Deep dives: [mechanisms.md §4](mechanisms.md#4-dev-environment-pipeline--pdshell)
(pdshell) · [§6](mechanisms.md#6-configuration-orchestrator--orc-configurationorchestrator)
(orc) · [§7](mechanisms.md#7-user-environment-layer--homeenv) (user-env layer).

### 4.4 External pure-config repos — the ×22 flake=false consumption path

The 22 `*-config` repos are **pure data sources** (they never participate in
flake evaluation): flake.lock pins the rev → Home Manager writes them into
`~/.config/<app>/` via orc orchestration at activation. The dual safety nets
are orthogonal: **the lock pins WHERE** (reproducibly fetched from where) ·
**the tests pin WHAT** (does what was fetched behave) — a bump touching only
the lock turns the tests red on behavioral breakage; behavior unchanged but
source moved keeps the lock green. Inventory and shared contracts:
[external-repos.md](external-repos.md); deep dive:
[mechanisms.md §8](mechanisms.md#8-external-config-repositories-flakefalse-inputs).

## 5. Naming Model (symbol-table semantics, index)

Directory names are the only naming identity source; arch never enters a
name (a pipeline value, not an address); the pipeline mints exactly one
synthetic name on nixosConfigurations (the legacy alias), guarded by Law G
to never shadow a real host. The full adjudication (consumer-verb semantics
· cross-domain coordinates · the complete Law G text) lives in
[mechanisms.md §3](mechanisms.md#3-dispatch-layer--targetsnix-target-factory).

| Output face | Key | Uniqueness source |
| ----------- | --- | ----------------- |
| `nixosConfigurations` | `<directory-name>` + legacy alias `<user>-<platform>` | directory names per-kind unique; alias guarded by Law G |
| `homeConfigurations` | `<user>@<directory-name>` | directory name × username (host layer may override user; the face follows) |
| `darwinConfigurations` | `<directory-name>` | directory name |
| `colmenaHive.nodes` | `<directory-name>` (= nixosHosts) | directory name (Law D pins emission coverage) |

## 6. Design Invariants

Machine-enforced invariants holding across the whole pipeline (each:
content → why → guard):

1. **One-way flow** — source → front-end → merge → synthesis → codegen →
   link → load, no reverse dependencies; module trees never import
   flake.nix / faces.nix. (The pipeline shape itself; module-reachability
   gate graph walk.)
2. **Controlled merge, never deep** — `//` with later layers winning; enum
   instances are attrsets, a deep merge would corrupt strategy payloads.
   (Law F throw · schema destructuring.)
3. **hostName force-alignment** — the loader dictates the directory name,
   no layer can win it back; hardware routing
   (`../hosts/${shared.hostName}`) therefore can never attach the wrong
   machine profile. (`lib_shared_targets` census item 6.)
4. **Per-host single instantiation (CSE)** — one `sharedByHost` table +
   handle passing; the default host's entry IS the base instance.
   (Evaluation discipline, T5.10; eager duplicate evaluation is a
   performance regression.)
5. **File presence = declaration** — the existence of deploy.nix/disk.nix/
   persist.nix IS "this host carries that fact"; absence means defaults.
   (The data + interpreter route, T5.12–T5.14; Laws B/C patrol for corpse
   files.)
6. **Capability in the platform structure tree, data in hosts/** —
   interpreter registration lives platform-side (disko/impermanence/
   sops-nix, one import line each), machine facts in hosts/. (Directory
   grammar v4 + the platform-grammar gate.)
7. **Identity SSOT distributed by value** — the fleet cache identity is
   single-sourced in `lang/const.nix`; faces that can evaluate consume it
   by value, those that cannot carry pinned literal mirrors, and the entry
   layer stays silent by law. (cache-ssot gate three-prohibition
   assertions.)
8. **Entry-layer silence** — flake.nix does input registration + one
   delegation line only; any assembly logic flowing back into the entry
   layer is an architecture regression. (The R31 refactor's end state;
   faces.nix header contract.)

## 7. Change Playbooks (pipeline view)

**Add a host:** one row in the `shared.nix` roles registry (pass 0) +
`mkdir hosts/<name>` + the class-key `shared.nix` (pass 0). Passes 1–6 all
follow automatically: inventory discovery → single instantiation →
classification → emission → faces. Zero flake.nix edits; Law E pins
registry ↔ directory zero drift in both directions.

**Add a platform:** the `platform/<tag>/{system,home}/` door directories
(pass 6) + one `enum.platform` caps-vector row (pass 1). The emitters route
automatically via the `platform/${tag}` interpolation; the platform-grammar
gate validates the directory shape.

**Add a role form:** one strategy-bundle row in the `enum.role` table
(pass 1). Immediately assignable from the registry; Law F's whitelist keeps
strategy keys only inside the bundle.

**Add a test:** register in the matching plane under `tests/` (the
nixosTest runner). Count anchors (README/test-matrix) travel with the test
in the same commit — a red docs-ssot gate is the drift alarm. env/dev
language directories map 1:1 to tests (one directory, one test — the gap
closed in full in R14).

**Change the fleet cache identity:** edit the `lang/const.nix` SSOT in one
place (pass 1); the literal mirrors (CI workflows · cachix.just · cache.md
prose) are hand-updated in the same commit, reconciled by the cache-ssot
gate.

**Migrate hardware facts:** `just hardware-migrate` (facter report +
wiring flip + legacy retirement); the end state is pinned by the
`lib_shared_targets` fact census.

---

*This doc evolves in the same commits as [mechanisms.md](mechanisms.md);
drift between the two is documentation debt — fix one, re-check the other.*
