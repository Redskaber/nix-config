# External repository layered classification — the four roles of the 47 inputs and their shared contracts (2026-10-16)

> English mirror of [docs/architecture/external-repos.md](../../architecture/external-repos.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> Background: the 47 inputs of flake.nix are not a flat list of equals — they fall into four roles, and the four tool repositories by the same author (nix-types / pdshell / configuration-orchestrator / nmt) each occupy a different pipeline layer. This document answers "which layer each external repository sits in, why, and which shared contracts it follows"; the inner mechanics of each repository live in their own dedicated documents (see the cross-references at the end), while this document covers only the layering facts and the contracts. All evidence is first-hand verified (file:line).

### 1. Classification master table (47 inputs = the evaluation-face attrNames)

| Category | Count | Members | Consuming layer |
| --- | --- | --- | --- |
| Upstream community | 14 | nixpkgs (stable) · nixpkgs-unstable (second instance, `shared.upkgs`) · nixgl · nur · home-manager · sops-nix · nix-darwin · disko · impermanence · nixos-wsl · colmena · hyprland · hyprland-plugins · pre-commit-hooks | per layer, as needed (dependency graph in [dependency-graph.md](dependency-graph.md)) |
| Self-owned tool libraries | 4 | nix-types · pdshell · configuration-orchestrator · nmt | §2 per-repository adjudication |
| Self-owned application flakes | 6 | wechat · unrpyc · cnmplayer · trae · z-library · zcode | consumed by reference from home/env |
| Self-owned non-flake sources | 23 | commit-config (commit toolchain) + 22 × `*-config` (externalized dotfiles: fcitx5 / nvim / emacs / kitty / hypr / waybar / …; full list in README §Directory structure, line 8) | orchestrated by orc into the home closure |

**The 47-vs-46 counting convention**: the README anchor sentence and the docs-ssot gate evaluate `builtins.attrNames inputs` (47); a textual grep for `.url = ` counts only 46 — `hyprland-plugins` is a pure follows input (no `.url`, carrying only `inputs.hyprland.follows`, sharing the same nixpkgs instance tree with the hyprland plugin ecosystem). Both numbers are correct; the conventions differ. In-repo references uniformly follow **47** (the evaluation-face/anchor convention); numbers under the grep convention never land in the docs.

**The discriminator for the four roles** (which category an input falls into comes down to three questions): is it maintained by the same author (→ self-owned); does it expose `lib`/`modules` for **architectural** consumption by this repository (→ tool library), or does it only enter closures as **payload** (→ application flake); does it require flake evaluation (of the 24 with `flake = false`, nmt and commit-config are a tool/toolchain while the remaining 22 `*-config` are pure data sources — the "×22" on README line 8 refers to the latter, excluding nmt and commit-config).

### 2. Layering of the self-owned tool libraries (four repositories, four layers — one repository per layer)

The four repositories are distributed orthogonally across pipeline phases — no two repositories share the same layer responsibility, hence no circular dependencies and no substitution relationships, only top-down one-way consumption:

```
lang 前端（Phase 1，无 pkgs）        nix-types
        ↓ 类型/ADT 供给
runtime（IR 合成，按 arch 解析）    pdshell（devShell 面）
                                    orc（配置树编排面）
        ↓ shared.* 短路径注入
faces（链接层）                     pdshells → devShells 输出
tests（Plane 5，零 VM）             nmt（模块系统测试框架）
```

#### 2.1 nix-types — the type foundation of the lang frontend (Phase 1)

- **What it is**: a pure-Nix algebraic data type library — enum constructors / exhaustive match dispatch / Option / Result ADTs, a lib core with zero nixpkgs coupling (only `builtins.*`), and a built-in version-identity assertion (`lib.version`).
- **Why this layer**: the lang stage exists before pkgs (the frontend of the two-stage initialization), and both the enum-ization of the policy tables and the Result railway must be available early in evaluation — nix-types' zero-dependency nature makes it the only external library that can enter Phase 1.
- **Consumption faces** (first-hand anchors): `lib/shared/lang/tools.nix:24` (short alias `nt` registered) → `lang/enum.nix:9` (16 policy tables), `lang/validate.nix:49` + `runtime/default.nix:22` (Result railway), `platform/nixos/system/wm/hyprland/plugins/default.nix:18` + `platform/nixos/home/wm/hyprland/default.nix:88` (exhaustive match dispatch).
- **Test safety net**: `tests/lib/shared/lang/` (behavior contracts of enum/validate) + `tests/lib/shared/lang/version.nix` (version-identity contract).

#### 2.2 pdshell — the devShell manager for runtime injection and faces emission

- **What it is**: a pipeline-style devShell manager — the `mk-pdshell` seven-stage FSM + the `pdshells` directory loader; ContextPhase is built on the enums of its sister repository nix-types.
- **Why this layer**: a devShell is a face that only takes shape at runtime (it depends on pkgs and on the user-policy IR), and its output face (the flake's `devShells` attrset) is emitted in the link pass by faces.nix — pdshell spans both the runtime and faces phases, but its type supply comes entirely from nix-types (pinned hard via follows).
- **Consumption faces**: `lang/tools.nix:31` (`pdshell-raw` registered) → `runtime/default.nix:99` (injects `shared.pdshells`) → `faces.nix:62` (`pdsh = shared.pdshells { … }`, one construction with two consumers: the devShells output + the docs-ssot gate count); the defining data lives in `home/env/dev/` (`devDir` of `shared.nix`).
- **Test safety net**: `tests/lib/shared/pdshell.nix` (five contract groups: directory loading, FSM phases, verbatim assertions on the parameter records).

#### 2.3 configuration-orchestrator (orc) — the configuration-tree orchestrator resolved by arch at runtime

- **What it is**: a pure-Nix configuration-tree orchestration library — discovery → include-intent policy → emitter dispatch (symlink / copy / text); `mergeHomeFiles` declaratively synthesizes the trees of the 22 external `*-config` dotfiles repositories.
- **Why this layer**: its lib is **arch-qualified** (`lib.${system}`) and can be resolved only at the runtime stage, keyed on `shared.arch.tag` — which is also why it is registered as `orc-raw` and re-published by runtime as `shared.tools.orc` (see the tools.nix header comment for the short-path table).
- **Consumption faces**: `lang/tools.nix:28` (`orc-raw`) → `runtime/default.nix:77` (arch resolution) → 7 theme stacks at the home layer (hyprland / quickshell / waybar / swaync / rofi / cava / kitty — `platform/nixos/home/wm/hyprland/default.nix:46` as the representative: `shared.orc.mergeHomeFiles (shared.orc.listFilesRecursive inputs.hypr-config "")`).
- **Test safety net**: the orc behavior tests in `tests/` + orc-guard (the guard contract that a non-empty include selecting nothing fails eval).
- **Naming adjudication**: the full flake-input name is `configuration-orchestrator`, and the prevailing in-repo short name is `orc` — the mapping is declared only here and in a tools.nix comment.

#### 2.4 nmt — the module test framework exclusive to the tests layer (flake = false)

- **What it is**: a GitHub mirror fork of rycee/nmt (the sourcehut primary returns 403 to Nix fetchers, hence the fork); the test framework of the Home Manager module system (package scrubbing + directory snapshot assertions). The fork delta is twofold: grep assertions pass `--` before the needle (preventing an option-styled needle from being taken for a flag); it carries its own regression battery.
- **Why this layer**: `flake = false` — nmt is a **test-time** dependency that enters no host closure; its single consumption point in the whole repository: `tests/nmt/default.nix:87` (Plane 5, 16 tests, `buildHomeManagerTest` self-implemented, zero VMs).
- **Test safety net**: nmt's own self-test battery + the 16 tests of this repository's `tests/nmt/`, which are themselves the proof of consumption.

### 3. Shared contracts (the integration discipline shared by the four repositories)

1. **Short-path registration (tools.nix as the single gate)**: integration of every tool library must be registered through `lib/shared/lang/tools.nix` — configuration files write `shared.tools.<alias>.<api>`, never `inputs.<long-name>.lib.<api>` directly. This keeps configuration files decoupled from flake-input naming: renaming an input or switching its source (e.g. nmt switching mirrors) touches exactly one place.
2. **The follows SSOT chain**: pdshell's nix-types is pinned with `follows = "nix-types"` to this repository's same instance — the type ADTs of the two repositories are forever same-source, with no `nix-types_2` dual-instance drift. Dependencies among the self-owned tool libraries always use follows; independent locks are not allowed.
3. **Dual safety nets (lock pins WHERE, tests pin WHAT)**: the rev in flake.lock answers "where to fetch from" (reproducible); the contract tests in tests/ answer "does what was fetched behave as expected" (evolvable). When a bump changes only the lock, a commit that breaks a behavioral contract turns the tests red; when the behavior is unchanged but the source moved, the lock stays green — the two safety nets are orthogonal, and neither can be dropped.
4. **Sandbox reference copies ≠ lock consumption**: the `~/nix-types`, `~/nmt`, `~/orc`, `~/pdshell` working copies cloned in the development sandbox are **read references** (for adjudication and documentation forensics); what the repository actually consumes is always the rev pinned by flake.lock. Reference copies running ahead of the lock is the norm (see nmt: the local HEAD is one commit ahead of the lock) — whether the lead gets bumped is adjudicated by the owner, with the documentation noting the pending state.

### 4. Bump discipline

- **When to bump**: when upstream has a needed capability/fix; never chase HEAD proactively (a tool library's value lies in stable contracts, not in novelty).
- **bump = lock + tests in the same commit**: after `nix flake update <input>`, run the full gate battery (six hygiene gates + plane tests) and commit only when green — the contract of item 3 under dual safety nets is honored here.
- **Fork repository (nmt), one extra step**: acceptance happens first in the fork repository (self-test battery green); the cadence of re-syncing upstream is adjudicated by the fork repository's own documentation; this repository cares only about the mirror's rev stability.

### Cross-references

- Type-system mechanics and adjudication history: [nix-types.md](nix-types.md)
- Inner mechanics of orc / pdshell: [mechanisms.md](mechanisms.md) (§4 / §6)
- The complete nmt guide: [../tests/nmt.md](../tests/nmt.md)
- Dependency graph (the upstream-community face): [dependency-graph.md](dependency-graph.md)
