# Peer-Project Comparison & Multi-Dimension Scoring — Snapshot Assessment (2026-10-30)

> **Positioning & shelf life**: this is a **point-in-time assessment**
> (snapshot), not an SSOT — peer repos keep evolving and scores decay;
> re-do the whole table when re-assessing and update the date on this line.
> The assessment is based on each repo's publicly observable README /
> docs / repository structure (facts observable on the assessment date),
> not per-repo cloned test runs.
> **Scoring rubric** (0–10): 0 absent · 3 basic (hand-rolled but works) ·
> 5 solid (customary best practice) · 7 excellent (beyond common) ·
> 9–10 exceptional (rare among peers / methodological contribution).
>
> **2026-10-30 R14 re-assessment note**: test planes 103→108 (the env/dev
> source:test 1:1 gap closed for five languages), devShells 25→27
> (haskell/ocaml added) — full table re-scored; two new dimensions (D17
> hardware/disk/state declarativity, D18 config externalization) bring the
> total base from /160 to /180. Recomputing column sums caught arithmetic
> drift in the previous totals row (m77 89→actual 95 · ryan 71→76 ·
> gvolpe 54→60 · mic92 82→80), corrected this round — the totals row now
> always equals the column sums.

## 1. Comparison Set

| Handle | Repo | Why included |
| ------ | ---- | ------------ |
| **this repo** | redskaber/nix-config (the subject) | multi-host · compiler-shaped pipeline · three-layer policy chain |
| **starter** | misterio77/nix-starter-configs | the de-facto community flake starter templates (standard/extended) |
| **m77** | misterio77/nix-config | the above author's personal config: multi-host · multi-platform (nixos/darwin) · library-leaning |
| **ryan** | ryan4yin/nix-config | the most-referenced desktop config in the Chinese community: multiple WMs · tutorial-style README |
| **gvolpe** | gvolpe/nix-config | Hyprland/niri desktop config + companion blog series |
| **mic92** | Mic92/nix-config | the sops-nix author's personal config: minimal · authoritative secrets practice |

The sample covers four shapes: **template** (starter), **teaching-style
personal config** (ryan · gvolpe), **engineer's personal config** (m77 ·
mic92), **platform-engineering personal config** (this repo).

## 2. Similarities (the shared genome)

All six repos share the 2026 "de-facto standard stack" of the NixOS
ecosystem — these similarities form the comparison baseline:

1. **Flakes as the unit of organization** — every repo enters through
   flake.nix; flake.lock pins the nixpkgs revision (one reproducibility
   baseline for all).
2. **Home Manager owns the user domain** — all integrate HM (standalone or
   module mode); dotfiles declared.
3. **A multi-host directory** — hosts/ (or an equivalent machines/) splits
   per machine; flake outputs address by hostname (this repo / m77 / mic92
   discover via readDir automatically; ryan / starter hand-write the
   roster).
4. **Channel discipline** — stable/unstable dual-channel or multi-channel
   consumption (varying degrees, same direction).
5. **Declarative secrets** — sops-nix or an equivalent (agenix) manages
   secrets (mic92 IS the sops-nix author; this repo adds a dual-domain key
   hierarchy).
6. **devShells** — all provide dev environments via flake devShells
   (varying depth).

## 3. Scoring Matrix (18 dimensions)

| # | Dimension | this repo | starter | m77 | ryan | gvolpe | mic92 |
| - | --------- | --------- | ------- | --- | ---- | ------ | ----- |
| 1 | Multi-host inventory & dispatch | 9 | 3 | 7 | 5 | 3 | 7 |
| 2 | Policy layering & abstraction | 10 | 4 | 6 | 4 | 3 | 4 |
| 3 | Type safety & validation | 9 | 2 | 3 | 2 | 2 | 2 |
| 4 | Test depth & structure | 9 | 1 | 4 | 2 | 1 | 3 |
| 5 | CI/CD completeness | 9 | 4 | 6 | 3 | 3 | 4 |
| 6 | Documentation system | 10 | 8 | 6 | 8 | 6 | 3 |
| 7 | Secrets management | 8 | 1 | 5 | 4 | 2 | 8 |
| 8 | Deployment channels | 8 | 2 | 6 | 3 | 2 | 5 |
| 9 | Reproducibility & pinning discipline | 9 | 6 | 8 | 6 | 6 | 8 |
| 10 | Cross-platform coverage | 9 | 4 | 8 | 3 | 2 | 4 |
| 11 | Modularity & reusability | 8 | 7 | 7 | 5 | 4 | 5 |
| 12 | Developer experience | 9 | 5 | 6 | 5 | 5 | 4 |
| 13 | Beginner adoptability | 4 | 10 | 6 | 9 | 7 | 5 |
| 14 | Cache & build-efficiency strategy | 8 | 4 | 5 | 4 | 3 | 4 |
| 15 | Code hygiene | 10 | 6 | 6 | 5 | 5 | 6 |
| 16 | Community scale & ecosystem influence | 3 | 8 | 6 | 8 | 6 | 8 |
| 17 | Hardware/disk/state declarativity | 9 | 3 | 6 | 6 | 3 | 6 |
| 18 | Config externalization & payload separation | 9 | 2 | 4 | 5 | 4 | 4 |
| | **Total (/180)** | **150** | **80** | **105** | **87** | **67** | **90** |

(The total is for ranking intuition only; dimensions are not
interchangeable — this repo's low-scoring rows are exactly what its
positioning implies, see §5.)

## 4. Per-Dimension Notes

**D1 Multi-host inventory & dispatch** — this repo 9: readDir inventory →
caps capability-table classification → four emitters (incl. the colmena
deploy face) + the Law E/G naming census (adding a machine = one registry
row + mkdir, zero flake.nix edits). m77 7: complete roster but hand-enumerated
host attributes; mic92 7: auto-discovery + plain, effective deploy scripts.
starter 3: the template shows a two-host shape, no dispatch.

**D2 Policy layering & abstraction** — this repo 10: the fleet → role →
host three-layer controlled merge + Law F whitelist + per-key `why`
provenance + layered schemas (fleet 16 / shared 18), with roles as
strategy BUNDLES (composition over override — the Kustomize doctrine).
m77 6: shared abstractions and library-leaning opts; others 3–4: flat
attrsets or simple shared modules.

**D3 Type safety & validation** — this repo 9: the nix-types ADT (enum
construction is exhaustive · Option/Result railway) + schema destructuring
validators + the i18n dual-source guard. Others 1–3: rely on Nix's lazy
eval failures (the ecosystem norm — exactly the differential bet this
repo makes).

**D4 Test depth** — this repo 9: 6 planes, 108 tests + 6 hygiene gates =
114 checks (QEMU VM-level + zero-VM nmt assertions + eval-depth censuses),
with count anchors machine-enforced and a 1:1 source:test mapping for
env/dev (sixteen languages, sixteen tests). m77 4: basic CI checks; mic92
3: a few tests; ryan/gvolpe/starter 1–2: nearly none (the dotfile-config
ecosystem norm).

**D5 CI/CD completeness** — this repo 9: ten stages (lint → face-sharded
deep-eval → vm-tests → closure-level → darwin leg → summary
reconciliation) + weekly automated flake-update PRs + opt-in cache pushes.
m77 6: multi-platform CI matrix; others 2–4.

**D6 Documentation system** — this repo 10: bilingual mirror plane
(structural parity + CJK purity enforced by a gate) + docs-ssot count
anchors + a TOC navigation battery + the eleven-mechanism deep dive +
pipeline pass cards (pipeline.md). starter 8: the template's docs ARE the
product, extremely dense; ryan 8: tutorial-style README, very friendly to
beginners; mic92 3: minimal README (a deliberate choice).

**D7 Secrets management** — mic92 8: the sops-nix author himself,
authoritative but plain; this repo 8: a dual-domain key-hierarchy state
machine (user/host) + registry-driven + template rendering + rotation
runbook + a nine-scenario handbook — deeper engineering, less authority
than the upstream author. starter/gvolpe 1–2: absent or left blank.

**D8 Deployment channels** — this repo 8: nixos-rebuild / home-switch /
colmena 0.5 three channels + deployment facts with a census law (a
deploy.nix on a non-NixOS host is an eval throw). m77 6: full
nixos-rebuild + darwin-rebuild coverage; mic92 5: scripted deploys.

**D9 Reproducibility** — mic92/m77 8: strict pinning discipline; this
repo 9: all 47 inputs locked (exact-rev tarballs or follows convergence)

+ the nix-types WHAT/WHERE double pin (lock answers WHERE, tests answer
WHAT — single-sided drift goes red) + the byte-equality roundtrip gate.
ryan/starter/gvolpe 6: standard flake.lock.

**D10 Cross-platform coverage** — this repo 9: nixos · darwin (aarch64) ·
wsl (standalone) · nixos-wsl (dual doors) · generic-linux — five shapes,
cross-system evaluation verified. m77 8: nixos + darwin + generic Linux.
Others 2–4: one or two platforms.

**D11 Modularity & reusability** — starter 7: the template IS the
reusable artifact; this repo 8: export/ upstreamable modules
(nixosModules/homeModules dual outputs + an interface-standards doc) +
overlays/pkgs discipline + a reachability gate against dead code; m77 7:
library-leaning opts practice. Others 4–5.

**D12 Developer experience** — this repo 9: 27 pdshell composable
devShells (combinFrom composition + four lifecycle hooks) + 98 recipes in
14 groups of just reference + on-demand service verbs. m77/ryan 5–6:
standard devShells + routine scripts; mic92 4: make/shell scripts.

**D13 Beginner adoptability** — starter 10: born for it; ryan 9:
tutorial docs + a Chinese-speaking community answering questions; gvolpe
7: blog companions. **This repo 4**: high methodological density (the
three-layer chain · six laws · the gate family) — a forker must first
absorb the "one compiler" mental model. A conscious trade-off: this is a
platform-engineering config, not an entry template.

**D14 Cache & build efficiency** — this repo 8: the fleet cache identity
SSOT distributed by value across three faces + entry-layer statutory
silence (the cache-ssot gate) + nix-fast-build whole-plane handoffs +
opt-in attic pushes. Others 3–5: default substituters or a single cachix
point.

**D15 Code hygiene** — this repo 10: pre-commit (nixfmt/statix/deadnix)

+ the module-reachability gate + the grammar gate + the testScript syntax
gate + docs-ssot + en-parity + cache-ssot — a six-gate family (a
structural defense against the class of "dead code invisible to the
gates" — the run #369 incident category). Others 5–6: routine
pre-commit or none.

**D16 Community & ecosystem influence** — starter/mic92 8 (the template
is widely referenced / sops-nix is ecosystem infrastructure) · ryan 8
(among the largest reference points of the Chinese community) ·
m77/gvolpe 6. **This repo 3**: a single-maintainer personal repo with no
spillover yet — the biggest gap, see §5.

**D17 Hardware/disk/state declarativity** — this repo 9: the machine-fact
trio fully declarative AND machine-patrolled — facter.json (nixos-facter
hardware fingerprint) + disk.nix (disko layout) + persist.nix (impermanence
state policy), the Law A/B/C fact census (exactly one fact source per
bare-metal host, corpse files and dual sources both red) + the
hardware-migrate runbook + the ephemeral-root VM test pinning the rollback
recipe; not a 10: the bare-metal migration leg remains open (on the honest
shortcoming list). mic92 6: a disko co-maintainer personally — tool
authority, plain usage in his own config; m77/ryan 6: disko/impermanence
in use, not uniform across hosts; starter/gvolpe 3: the standard
hardware-configuration channel.

**D18 Config externalization & payload separation** — this repo 9: 22
external `*-config` repos (flake=false) as pure data sources, with the
**lock pins WHERE / tests pin WHAT** dual safety net (a lock-only bump
with broken behavior goes red via tests; a moved source with unchanged
behavior stays green), orchestrated onto ~/.config/ by orc —
externalization as an explicit architectural decision, not a habit; not
a 10: the external repos' own hygiene is outside this repo's gates.
Others 2–5: configs mostly managed in-repo (starter's teaching-focused
inclusion is the right call); ryan 5: app configs in-repo but well
documented.

## 5. Overall Positioning

**This repo's self-positioning**: treat a personal NixOS configuration as
a **platform-engineering project** — replace "one big attrset" with a
compiler-shaped pipeline (source → front-end → merge → IR → codegen →
link → load), and replace verbal discipline with machine-enforced laws
and a gate family. Among peer personal configs this is a
**methodological difference** (the source of the 9–10s on D2/D3/D4/D15),
paid for by the low D13/D16 scores: a steep learning curve, no community
spillover, single-maintainer risk.

**One-line relation to each peer**:

+ To **starter**: complementary, not competitive — this repo is "the
  second stop after graduating from starter"; the ideal adoption path is
  starter → practice on m77/ryan → evaluate this repo's methodology when
  governing multi-host, multi-platform fleets.
+ To **m77**: the closest fellow traveler in spirit (library-leaning ·
  multi-platform · auto-discovery); this repo walks further along the
  same direction (type system + gate family + three-layer policy chain).
+ To **ryan**: the mirror opposite on the documentation axis — ryan
  flattens the curve for beginners, this repo raises the ceiling for
  engineers; ryan's community operation is worth learning.
+ To **gvolpe**: a contrast in desktop-experience depth (gvolpe's
  hand-polished Hyprland/niri vs this repo's strategy-bundle-driven wm
  trees — trading hand-tuned detail for one-key form switching).
+ To **mic92**: a contrast in secrets management and minimalism — mic92
  proves a personal config can be "small and correct"; this repo chooses
  "large and self-verifying" (every structural claim gets a gate). Two
  ends of a spectrum, no better or worse.

**An honest shortcoming list** (by fix priority):

1. **No community** (D16=3): no issue templates / CONTRIBUTING / external
   contributors.
2. **Beginner threshold** (D13=4): no "minimal usable subset" onboarding
   path (the quickstart targets full bootstrap, not gradual adoption).
3. **Bus factor = 1**: the methodological density is itself a
   comprehension tax.
4. **Build-level tests need KVM/CI**: sandboxed / KVM-less environments
   can only run eval depth (partially mitigated by interpolating the
   assertions into testScript — evaluating executes the assertions).
5. **Desktop hand-polish depth**: the wm theme stack is mostly
   parameterized by strategy bundles, less hand-tuned than gvolpe/ryan.

## 6. Cross-Learning Checklist (what to borrow from peers)

| Source | Borrowable item | Suggested landing spot |
| ------ | --------------- | ---------------------- |
| starter | minimal-usable-template extraction | extract a "three-layer minimal example" from this repo as a progressive tutorial in docs/guides/ (the quickstart has the skeleton; add the minimal set) |
| ryan | tutorial-style docs + community operation | add an illustrated pipeline section to the README (the current ASCII diagram is dense for newcomers); open issue templates |
| m77 | the library upstreaming path | keep upstreaming export/ modules (interface-standards.md already fixes the contract) |
| mic92 | the minimalist audit | periodically ask "can this gate/law retire?" — a mechanism-budget review (the mitigation for §5 shortcoming 3) |
| gvolpe | blog-style output | the eleven-mechanism docs can become a blog series (external output = the only viable fix for D16) |

---

*Methodology memo: scores are derived from publicly observable repo
structure (directory shape · CI workflows · test directories · docs
scale), one rubric across repos; the "this repo" column reflects the
actual state at this document's HEAD (108 tests + 6 gates = 114 checks
with static anchor accounting consistent, bilingual doc plane, six-gate
family in place; derivation-level build green awaits CI after the push).
If a peer description has drifted, that peer's official README wins —
this doc does not lock in their future.*
