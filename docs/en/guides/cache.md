# Cache Guide — Local Pull and Push (the redskaber-nix-config public layer)

> English mirror of [docs/guides/cache.md](../../guides/cache.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document covers the local workflows outside CI: **pull** (any machine,
> zero authentication) and **push** (the owner-side verb, requires an auth
> token). For the CI-side wiring (PULL ×11 legs extra-conf + PUSH two steps),
> see [.github/workflows/ci.yml](../../../.github/workflows/ci.yml) and
> [the README's CI/CD section](../../../README.en.md#cicd-complete-execution-flow);
> the two documents share one source for different audiences: the CI grammar
> answers "why it is designed this way," while this document answers "how do I
> use this cache on my machine."

## What the cache is (one paragraph)

A public Cachix cache, `redskaber-nix-config` (ZSTD, priority 41, public key
`redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw=`).
It serves exactly one purpose: **the Hydra gap created by pinning the lock to
the nixos-26.05 moving-branch HEAD** — the lock moves faster than the channel's
binary progress, and the closure-building tail of a cold run (historically
measured at 1h+) collapses into substituted downloads once this cache holds
content. priority 41 stays behind cache.nixos.org (40): paths present on both
sides always go through the official one — the free tier's 5 GB is spent only
on the gap the official cache cannot catch up with.

**Single source of identity (SSOT)**: cache identity (name/URL/public key) is
declared only in `lib/shared/lang/const.nix` (`shared.const.cache.fleet`) and
is distributed per each face's capabilities: nix consumer faces **consume by
value** — platform/nixos/system/core/base/nix.nix (host-side composition on
NixOS), platform/darwin/system/nix (the darwin host side), and
home/core/base/nix.nix (the standalone user plane added in round 30, gated on
caps.system-nix) all reference `shared.const.cache.fleet`, so drift is
impossible; faces that cannot evaluate hold a **pinned literal mirror** — the
CI workflows, scripts/just/cachix.just (YAML/shell faces cannot import nix),
and this document's prose. flake.nix carries **no** cache identity (round 27
adjudication: zero cache identity at the entry layer — the real consumer faces
[hosts ×3 + CI] are all closed out, a flake-level literal would be the only
mirror face that "can evaluate the const yet holds a literal," and nixConfig's
trust semantics are a liability rather than a service for external consumers —
accept-prompt friction + silent ignoring under untrusted users; consumers
without a host-side nix.conf opt in explicitly via the three pull forms in this
document). The sixth repository hygiene gate `tests/cache-ssot.nix` pins every
mirror to the const value and pins flake.nix's silence as an assertion (any
nixConfig regression is an immediate CI red light).

**Client-side override priority**: if you need this cache to take absolute
precedence (fetching even the paths the official cache also has from here),
append `?priority=30` after the substituters URL (nix's per-URL priority
override — anything below 40 sorts ahead of cache.nixos.org) — the default is
not to do this: query order is dominated by each cache's self-reported priority
(list position only breaks ties), and 41's positioning reserves the free-tier
quota for the gap the official cache cannot catch up with.

## Pull (any machine, no token required)

Two equivalent machine-persistent forms; both land in the machine's nix.conf — plus the session-scoped Form 3 (zero disk footprint) at the end of this section:

**Form 1: one command via the cachix CLI** (recommended for permanent machines)

```bash
# the CLI comes from the pinned nixpkgs (same source, same discipline as CI; nothing to install on this machine)
nix run nixpkgs#cachix -- use redskaber-nix-config
```

`cachix use` picks its landing spot automatically from the machine's form
(`-m` can specify it explicitly): `nixos` (generates an /etc/nixos config
snippet) / `root-nixconf` (writes /etc/nix/nix.conf) / `user-nixconf` (writes
~/.config/nix/nix.conf, the single-user install form).

**Form 2: manual nix.conf** (the explicit form for controlled environments /
sandboxes — the same one the CI legs use)

```conf
# ~/.config/nix/nix.conf (or /etc/nix/nix.conf, depending on the install form)
substituters = https://redskaber-nix-config.cachix.org https://cache.nixos.org
trusted-public-keys = redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

**Form 3: session-scoped** (the NIX_CONFIG environment variable — zero disk
footprint; the process tree of one command is the entire scope)

```bash
NIX_CONFIG="
substituters = https://redskaber-nix-config.cachix.org https://cache.nixos.org
trusted-public-keys = redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
" nix build github:Redskaber/nix-config#checks.x86_64-linux.module-reachability-check
```

The very top of the nix configuration precedence chain: NIX_CONFIG shadows all
file configuration (user files and system files all yield) — hence this form
carries the **complete** two lines rather than an append. If you want to append
only this cache while keeping the built-in defaults (cache.nixos.org and its
public key), use the append form of the list-type settings:
`extra-substituters = https://redskaber-nix-config.cachix.org`
+ `extra-trusted-public-keys = redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw=`
(the extra-* pair is equivalent to the complete two lines above — the built-in
defaults are, after all, only the official source). Three consumption
scenarios: one-off environments (CI-style containers / sandbox sessions) with
zero disk footprint; borrowing someone else's machine without changing any
configuration; experiencing the cache's benefit first before deciding to make
it permanent (upgrading to Form 1/2).

**Verify the pull configuration took effect**:

```bash
nix store ping --store https://redskaber-nix-config.cachix.org
# when the cache is empty, narinfo 404s are harmless no-ops; nix falls back to cache.nixos.org naturally
```

Pulling **requires no** auth token — a public cache with zero authentication.
This is also why the unconditional ×11 PULL legs on the CI side hold (see the
pinned Install Nix extra-conf of each leg in
[.github/workflows/ci.yml](../../../.github/workflows/ci.yml)).

**darwin host runtime note**: darwin-rebuild uses /etc/nix/nix.conf — the
platform side's platform/darwin/system/nix generates it (nix-darwin's nix
module, the same single source of identity as the NixOS hosts:
shared.const.cache.fleet consumed by value; the pull side closes four faces:
CI runner · NixOS host · darwin host · standalone user plane; the flake entry
layer carries no cache identity, see "Single source of identity" above).
nix-darwin takes over the installer's /etc/nix/nix.conf via a known-hash
allowlist, and a switch writes it to disk; darwin machines not managed by this
flake still use Form 1/2.

**Standalone user plane (round 30)**: standalone-HM hosts without a system
layer, such as hosts/wsl, cannot be reached by the fleet at /etc/nix/nix.conf
— the shared tree home/core/base/nix.nix renders ~/.config/nix/nix.conf (+
registry.json) via home-manager's native `nix.settings`, consuming the same
identity by value with the same set of experimental-features. Two notes:
① in the nix.conf precedence chain, user files shadow system files per
setting (list types are replaced wholesale), so this plane renders only in
forms with no system nix plane (gated on caps.system-nix; nixos/darwin hosts
keep the system plane single); ② in the daemon form, user-level substituters
take effect only if the user is trusted (single-user installs carry no such
prerequisite) — trust is a distribution-side machine property, the same
root problem as trusted-users on the NixOS host side.

## Push (the owner-side verb, requires a token)

**Preferred form: the in-repo verb pipeline** (the token is resolved from the
secrets system; no manually set environment needed):

```bash
just cachix-status                 # a pre-push glance: reachability / trust / the state of both halves
just cachix-token                  # one-time: register the cachix-token secret + guided value entry
just cachix-push /nix/store/...-nixos-system-...
# or build-and-push in one go:
nix build .#checks.x86_64-linux.module-reachability-check --no-link && \
  just cachix-push $(nix build --print-out-paths .#checks.x86_64-linux.module-reachability-check)
```

The verb's resolution chain: the token comes from the `CACHIX_AUTH_TOKEN` env
→ the secrets system (the blob landed by `just cachix-token`, **leaf
extraction of the bare value**); the cachix binary comes from `$CACHIX_BIN`
→ PATH → `nix shell nixpkgs#cachix`. Multiple paths are pushed in one go,
each path pushed with its **complete closure**.

**The underlying CLI** (what the verb wraps — use it to understand the
semantics, or when working outside this repo):

```bash
# land the token once (created on cachix.org → the cache settings page, written to this machine)
nix run nixpkgs#cachix -- authtoken <CACHIX_AUTH_TOKEN>
# lands in ~/.config/cachix/cachix.dhall; or pass it each time via the CACHIX_AUTH_TOKEN environment variable

# explicit-path push
nix run nixpkgs#cachix -- push redskaber-nix-config \
  /nix/store/...-nixos-system-...

# stdin pipe (the CLI's classic shape — with no PATHS argument and stdin not
# a TTY, it reads newline-separated paths from stdin)
nix-store -qR /nix/store/...-nixos-system-... \
  | nix run nixpkgs#cachix -- push redskaber-nix-config
```

**The CLI form's iron law**: `cachix push CACHE-NAME [PATHS...]` — **the cache
name is the mandatory first argument** (one token can serve multiple caches);
when omitted, the first store path is silently taken as the cache name
("cache not found"), and with no paths the CLI waits on stdin — the CI push
step once omitted it, and local CLI verification caught and fixed it (the
step's opt-in kept it from ever having run live — the first half of the fifth
defect-becomes-gate case; the cache-ssot gate now pins the CI file's three
literals — cache name/URL/public key — as mirror assertions).

**Push semantics** (same source as the CI step):

- **Closure**: each path pushes its complete closure, not the single path
- **Chunk deduplication**: chunks the cache already holds are skipped —
  re-pushing is a no-op, idempotent
- **ZSTD**: the compression method declared by the cache; the CLI complies
  by default

**The typical local-push scenario**: after `just deploy` on kilig-nixos, the
owner runs `just cachix-push` on the side to push the new toplevel up — the
next CI run substitutes away the cold-build tail directly (precisely the
lesion behind the two 90-minute timeouts, 38085235502 / 38385434464). Both
CI-side legs, host-toplevels and darwin-toplevels, push automatically too
(they take effect opt-in once the owner sets `secret.CACHIX_AUTH_TOKEN` —
tracked as known-boundary ledger #3) — local and CI pushes jointly maintain
the same cache and never conflict (chunk deduplication is the backstop).

## Boundaries and principles

- **Distribution logic belongs to the distribution layer**: substituters
  belong to the machine's nix.conf (generated for NixOS hosts by
  platform/nixos/system/core/base/nix.nix, for darwin hosts by
  platform/darwin/system/nix, and for standalone-HM hosts by
  home/core/base/nix.nix [user-level ~/.config/nix/nix.conf, round 30]) or
  the runner's extra-conf — the flake.nix entry layer carries no cache
  identity (round 27 adjudication, see "Single source of identity" above;
  the gate pins the silence as an assertion). The cache identity itself is
  single-sourced in lib/shared/lang/const.nix and distributed per each
  face's capabilities (see "Single source of identity" above). Builds never
  depend on the cache's existence — outputs, lib, and hosts evaluate with
  zero awareness of the cache; when the cache is absent, everything builds
  from the official source as usual.
- **Honest quota accounting**: closures cost roughly 1–1.5 GB ZSTD per
  generation, the lock updates weekly → the 5 GB free tier fills in about
  3–4 generations. When full, clear old generations from the cachix.org
  dashboard; for the scale-out exits (self-hosted attic / harmonia reusing
  kilig-nixos at zero marginal cost) see
  [.github/workflows/cache-attic.yml](../../../.github/workflows/cache-attic.yml)
  (the attic dual-track contingency, gated on vars).
- **Pulling is always safe**: a 404 is a no-op; only a public-key mismatch
  fails hard (which means the key was configured wrong — not a problem with
  the cache).

## Troubleshooting quick reference

| Symptom | Attribution and remedy |
| --- | --- |
| `cache not found` | `cachix push` omitted the mandatory first argument, the cache name — see "The CLI form's iron law" above |
| Push hangs without moving | No PATHS and stdin is not a TTY — the CLI is waiting for paths on stdin; use `</dev/null` or supply explicit paths |
| `Neither auth token nor signing key` | Push is missing a token: land it via `authtoken` or the `CACHIX_AUTH_TOKEN` environment variable |
| No substitution happens, everything builds locally | Check `nix store ping`; confirm the substituters line has not been overridden (by one with higher priority) |
| `is not signed with any of the expected keys` | The public key was transcribed wrong — check it character by character against the "What the cache is" section of this document |
