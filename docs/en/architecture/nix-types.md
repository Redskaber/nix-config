# nix-types integration adjudication — inventory of the status quo and reference evolution (2026-10-11)

> English mirror of [docs/architecture/nix-types.md](../../architecture/nix-types.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> Background: nix-types (github:Redskaber/nix-types, a flake input of this repository, URL pinned to rev a1a2a13) is the same author's pure-Nix algebraic data type library — enum constructors / exhaustive match dispatch / Option / Result ADTs, a lib core with zero nixpkgs coupling (only `builtins.*`), self-certified by 440 tests. This document inventories its existing consumption faces in nix-config, adjudicates the "source-scopes mechanical enum-ization" proposal, and registers idle capabilities and upstream documentation debt. All evidence is first-hand verified (file:line).

### 1. Status quo: not a candidate — already the type-layer foundation

- **Input declaration**: flake.nix `nix-types.url = "github:Redskaber/nix-types/a1a2a13…"` (rev pinned hard); pdshell pins to the same instance with `follows = "nix-types"` (the comment explicitly guards against nix-types_2 drift — SSOT).
- **Three-layer consumption** (4 first-hand anchors):
  1. **Enum constructors**: `lib/shared/lang/enum.nix` `inherit (inputs.nix-types.lib) enum;` — platform / version / arch / portal / window-manager / display-manager / sound / shell / drive-group / editor / editor-set / terminal-set / browser-set / app-set / service-profile / pointer-cursor, 16 policy tables in active service in total (the drive table is reserved by a comment), all constructed as enum ADTs (payload rows carrying caps vectors, policy functions, and set routing).
  2. **Result railway**: `lib/shared/lang/validate.nix` and `lib/shared/runtime/default.nix` `inherit (inputs.nix-types.lib) result;` — ok/err/andThen composed over the data-driven pass lists, with `unwrapOrElse throw` as the repository's only throw boundary (Err diagnostics become eval errors verbatim).
  3. **Exhaustive match dispatch**: `platform/nixos/system/wm/hyprland/plugins/default.nix` over shared.version (v25_11 / v26_05 must be answered explicitly, no silent else); `home/wm/hyprland/default.nix` over shared.platform (an explicit nixos row + wildcard fallback).
- **Regression lock**: `tests/lib/shared/lang/` — 5 files, 732 lines — real production imports + pinned-rev assertions (the truthfulness discipline); any bad bump of nix-types is caught during this repository's CI evaluation phase.
- **Zero conflict with the dual-source contract**: nix-types lib imports no nixpkgs; the stable/unstable splicing governed by `sameSource` (fn.nix) is orthogonal to it.

### 2. Proposal review: mechanical enum-ization of source-scopes — rejected

Proposal: replace the source-scopes string-key dispatch in `lib/shared/runtime/default.nix` with `enum "nixpkgs-source" { stable = pkgs; unstable = upkgs; }` + match. Three pieces of evidence (all first-hand verified):

1. **Lexical scope of the schema default**: the default of `nixpkgs-source ? "stable"` (the schema.nix i18n section) is evaluated within schema.nix's own scope; the enum tables are constructed in the sibling module enum.nix. Without rewiring phase 1, the schema cannot carry an enum-instance default — fields with defaults must either stay strings or be forced into required-ness (boilerplate declarations added for every host, violating the original intent of T4.0's "default materialization").
2. **String consumption faces**: `home/core/base/i18n.nix` and `platform/nixos/system/core/base/i18n.nix` interpolate the declared source directly into the diagnostics of the sameSource guard (`${shared.i18n.nixpkgs-source}`); interpolating an enum instance depends on `__toString`, which changes the diagnostic semantics (label vs. declared literal).
3. **Diagnostic-quality regression**: a missing `.${str}` attribute → Nix attribute-missing (without the legal face); match on a non-instance input → validateInputType throw (without repair guidance). The existing hand-written throw carries all three of **illegal value + legal face + repair location** — exactly the shape of a proper frontend assertion.

**Adjudication**: mechanical enum-ization rejected; the equivalent micro-fix landed instead — the legal face in the diagnostic is derived from `builtins.attrNames source-scopes` (single source of truth: adding a scope updates the diagnostic with zero changes). **Reopening condition**: if nix-types provides a `parse`/`fromString` bridge (string → instance construction, diagnostics carrying the legal face), this proposal can be reopened under the T10.1 pattern (schema-required key + payload enumeration + exhaustive dispatch).

### 3. Landed actions (this commit batch)

- **runtime**: the legal face of source-scopes is now data-driven (the micro-fix above).
- **flake**: the nix-types input URL is pinned to rev `815fc3f…` (upstream has no tags — `git ls-remote --tags` is an empty set — a 40-hex SHA is the only pinnable form), in the same family as 9ebe543's action-SHA machine contract: weekly updates no longer drag nix-types HEAD along, and an upgrade goes from "surprise" to "deliberate decision"; the 732-line battery + nix-types' own 440-test checks.testSuite are the dual safety net against bad bumps.

### 4. Idle-capability register (for future dispatch, not a commitment)

| Capability | Shape | Trigger scenario |
| --- | --- | --- |
| `serialize` | instance → flat JSON-safe (tag/typename/value) | a ready-made primitive whenever the debug face (`nix eval .#debug`) needs to dump platform tables / policy tables |
| Multi-instance match + specificity | `Red._` takes precedence over `._._`; dual list/attrset shapes | when "platform × version" two-dimensional dispatch appears (hyprland plugins is the one-dimensional forerunner) |
| `isType` fingerprint | `__meta__.variantNames` distinguishes same-named enums with different variant sets | when a test assertion needs to pin down enum identity by equality |

(Before T25 the `lib.version` assertion sat idle in this table — its trigger scenario has since been realized; see the landing record in section 5.)

### 5. Upstream documentation-debt settlement and the version-identity contract (T23, 2026-10-12)

- **Dead-reference repair**: the originally registered PATTERNS.md "owner's local un-pushed commit 61bc6ce" was **utterly lost** in the sandbox-environment rebuild (the fresh clone's object store has no such commit, the GitHub-side HEAD is still 815fc3f, no reflog) — that register used to be the only delivery evidence. It has since been rewritten and extended: two commits on the nix-types `evolve/t23-version-identity` branch (`2fd8779` PATTERNS.md seven patterns + `d973191` version identity, ordered base → extension), delivered via the web full-package download interface; until the push, any reference defers to that patch. Enhancements over the original draft: a new Version contract pattern (when the original draft was written, `lib.version` did not yet exist) and a precedent list of "when not to enum-ize" (the knowledge sedimentation of this document's section-2 adjudication).
- **Version identity (T23.1, nix-types 3.6.0)**: `lib/version.nix` single-sources `version = "3.6.0"`, merged at the top level of `lib/default.nix`; locked by the six laws of test suite No. 17 (existence / semver shape / pinned-value truthfulness discipline / no-leak boundaries ×3 — the enum type face, instance records, and `__meta__` carry none of it); the derivation name `nix-types-${version}` and the demo banner share the same source (the old hand-written `v3.4` lagged two versions behind). **Verification upgraded from static to evaluation**: the sandbox rootless nix (`~/nixroot/nx`, 2.35.2) survived for reuse — 446/446 real evaluations green.
- **Downstream assertion (landed, T25)**: the owner has pushed nix-types (`a1a2a13` — the T23 two commits adopted via squash); this repository lock-bumped (`815fc3f → a1a2a13`, flake.nix pin + narHash synced) and the lang battery landed the version-contract assertion: `lib_shared_lang_version` (test No. 97, tests/lib/shared/lang/version.nix — the originally registered candidate No. 96 was taken by T24's `lib_shared_overlays`, so it slipped one slot) asserts `inputs.nix-types.lib.version == "3.6.0"` — the rev pins "where", the version assertion pins "what", and a bad bump moves up from "an attribute missing three layers downstream" to "a one-line red pinpointing both sides" (mutation-check observation: a fake expected → a throw reporting all three parties — lock rev / expected / observed — plus two-file reconciliation guidance). The two-file deliberate-decision shape of a bump: flake.nix pin + test expected — single-sided drift turns red immediately.
