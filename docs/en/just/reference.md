# Complete just command reference — 98 recipes × 14 groups

> English mirror of [docs/just/reference.md](../../just/reference.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document is the full version of the README's "justfile command reference"
> section (migrated verbatim out of the README during the T13.1 layered refactor).
> `just --list` gives the same-source entry points in the terminal; for the daily
> quick reference (the three high-frequency groups deploy / devenv / secrets) see
> the [README](../../../README.en.md#daily-operations-quick-reference).

> The full verb surface has 98 recipes, annotated `[group]` into 14 groups
> (bootstrap / cachix / commit / deploy / devenv / disk / flake / hardware / keys /
> maintenance / rules / secrets / services / shared) — `just --list` gives every
> entry point organized by group; bare `just` (no arguments) prints the start-here
> map; the secrets-side lifecycle map is entered from `just secrets-guide`.
> Introspection: `just <recipe> --evaluate` prints any recipe's variable
> evaluation and its expanded command body (without executing) — a self-service
> troubleshooting surface for interactive workflows.
>
> Description convention (R28): `just --list` displays the **last consecutive `#`
> comment line** above the recipe — that line must be a complete, concise,
> self-contained single sentence (examples and supplementary notes go above it,
> never as the final line).

### Global (bootstrap entry points)

```bash
# Full initialization (new machine) — <username> is the only required argument:
#   1. docs/tmpl/shared.nix.tmpl → shared.nix (policy source of truth)
#   2. generate hosts/<hostname>/hardware.nix (current hardware probing)
#   3. initialize sops: directory + user age key + .sops.yaml rule baseline
just init <username>

# Server machine straight to dual keys (when host key material is prepared first, the state machine hops ahead):
#   first generate the host keypair (out-of-repo delivery copy), then feed the public key into bootstrap:
just key-new-host <alias>            # generate the keypair, print the public key
just init <username> <alias> <age1...> # EMPTY → USER+HOST direct

# own host = srv host (the personal machine also runs the srv services) — the host private key lands on this machine:
just key-install-host <alias>        # merge the identity into this machine's sops key file
# (after the srv policy is hardened this machine can still decrypt; the delivery copy can be shredded at this point)

# POST-BOOTSTRAP (shared.nix already exists)
just secrets-init [alias age1...]    # initialize only the sops infrastructure (optional direct dual-key)
just secrets-plan-create           # generate the plaintext template reference
just rules-init                    # rebuild only when .sops.yaml is missing (refuses on already-evolved files)
```

### deploy — hosts & deployment targets (T2.4, data-driven)

> The host inventory is enumerated from the hosts/ directory and auto-discovered
> by the flake — adding a machine = `mkdir hosts/<name>`
>
> - Two files, zero flake changes; the recipes here are likewise zero-hardcoded.

```bash
just hosts-list                 # list all evaluable hosts (nixosConfigurations keys)
just home-targets               # list all standalone home-manager targets (<user>@<host>)

just nixos-switch <host>        # NixOS switch (= sudo nixos-rebuild switch --flake .#<host>)
just nixos-test <host>          # test mode (no boot entry written; discarded on reboot)
just nixos-boot <host>          # boot mode (T10.2: set only the next-generation boot entry, no activation — takes effect on reboot)
just home-switch <host>         # HM switch (reads the shared.nix username → <user>@<host>)

# colmena remote deployment plane (T20.1) — same module tree, same policy IR; the CI lock emits an equivalent:
just deploy-list                # list the colmena deployment plane (= nixosHosts; darwin/HM use their own verbs)
just deploy <host>              # remote deployment: build → upload → activate (ssh, policy user; CLI pinned at v0.5.0)
just deploy-local               # local deployment (apply-local --sudo; requires the hosts/<h>/deploy.nix switch)
# Example: just nixos-switch nixos / just home-switch wsl / just deploy nixos
```

### shared — policy-layer generation

```bash
just shared-generate <username>  # generate shared.nix from the template (the only legal way to write it)
just shared-show-username        # show the username currently in shared.nix (diagnostics)
just shared-validate             # verify the template placeholders exist
just shared-roundtrip            # verify shared.nix ⇄ template byte-identical regeneration in both directions (same source as the gate)
```

### hardware — hardware configuration

```bash
just hardware-migrate         # one-shot migration: hardware.nix → facter.json (T19.1; probing report + mounts/kernelModules
                               # carried verbatim into the host entry + wiring flipped + legacy file retired; end state locked by the fact-source census)
just hardware-facter           # generate hosts/<hostname>/facter.json (declarative route, T5.12; first run or after a hardware change)
just hardware-generate         # generate hosts/<hostname>/hardware.nix (legacy route, nixos-generate-config)
just hardware-show             # show the current hardware.nix contents
just hardware-list             # list all configured hosts
just sound-audit               # read-only: collect this machine's audio-form evidence (the semantic half of debt #9, T17.1) —
                               # probe the form from runtime facts (WSL / VM / bare metal), and print the matching
                               # adjudication-matrix row and the suggested flip (dossier: docs/guides/sound-adjudication.md)
```

### disk — disk-layout application + state-policy inspection (T5.13 + T5.14)

```bash
just disk-show <host>          # read-only: evaluate the derived result of the host's disko layout (fileSystems/boot wiring)
just persist-show <host>       # read-only: the host's state contract (survival inventory + ephemeral-root rollback recipe)
just disk-format <host>        # destructive: build the pinned partition/format/mount script from the locked closure and run it
                               # (reinstall/installer scenario; extra args passed through, e.g. --dry-run)
```

### services — on-demand service management

```bash
# Immediate start/stop (not persistent; lost on reboot)
just service-start <name>        # systemctl start
just service-stop <name>         # systemctl stop
just service-restart <name>      # systemctl restart
just service-status <name>       # systemctl status

# Boot autostart management (persistent, across reboots + rebuilds)
just service-enable <name>       # systemctl enable (auto-starts after reboot)
just service-disable <name>      # systemctl disable (no autostart after reboot)
just service-is-enabled <name>   # check whether autostart is enabled

# Database aliases
just db-start <name>             # = service-start
just db-stop <name>              # = service-stop
just db-enable <name>            # = service-enable
just db-disable <name>           # = service-disable
just db-list                     # list all database services
just autostart-list              # list all enabled services
```

### flake — dependency management

```bash
just flake-update-all            # update all inputs
just flake-update <pkg>          # update a single input
just flake-update-not-sops       # update all inputs except sops-nix (the sops-nix version is locked)
just flake-update-configs        # update only the *-config inputs (external config repositories)
just flake-update-dry            # dry-run: preview which inputs would change (does not modify flake.lock)
just flake-show                  # show all flake outputs (including devShells)
just flake-lock-show             # show the currently locked versions (read-only)
```

### devenv — development environments

```bash
just devenv-create rust                     # create a single-language profile (usable offline)
just devenv-create-from python renpy        # create a composite-variant profile
just devenv-use rust                        # enter an existing single-language environment
just devenv-use-from python machine         # enter an existing composite-variant environment
just devenv-update rust                     # force-rebuild a single-language environment
just devenv-update-from python machine      # force-rebuild a composite-variant environment
just devenv-delete rust                     # delete a single-language profile
just devenv-delete-from python renpy        # delete a composite-variant profile
just devenv-create-all                      # create all known environments (including composite variants)
just devenv-delete-all                      # delete all profiles (for forced rebuilds)
just devenv-update-all                      # delete and rebuild all environments
just devenv-show                            # list all devShells available in the flake
just devenv-list                            # show created profiles as a tree
```

**Profile naming rule:** `<username>-<lang>[-<class>]`, stored under
`~/.local/state/nix/profiles/dev/<lang>/`.

### secrets — keys & encryption (three objects × lifecycle verbs, registry-driven)

> The entry point is `just secrets-guide` (state machine + verb matrix + scenario
> flows); `just secrets-list` answers "which secrets exist, which is missing" at
> any time.
> The template `docs/tmpl/sops/sops-rules.yaml.tmpl` carries a dual rendering
> mode: the user key row renders unconditionally, while the host key row (marked
> `# __HOST__`) is decided by the bootstrap invocation.
> The repository carries the **maintainer's** ciphertext (undecryptable by you) —
> the fork-takeover procedure is in
> [docs/architecture/mechanisms.md §5 security layer](../architecture/mechanisms.md#5-security-layer--sops--age-layered-management).

```bash
# ── Bootstrap (BOOTSTRAP, requires just shared-generate <username> first)────────────
just secrets-guide                # lifecycle map: state machine / verb matrix / scenario flows (start here)
just secrets-init                 # directory + user key + rule baseline (USER_ONLY)
just secrets-init <alias> <age1...> # straight to dual keys (EMPTY → USER+HOST, host row rendered)
just secrets-init-with-plan       # same as secrets-init + generate all plaintext template instances

# ── secrets: secret values (REGISTRY-driven, alias → shared.nix dotted key)─────────
just secrets-list                 # alias table × domain × encryption status (what is missing at a glance)
just secret-set <alias>           # interactively encrypt one secret (upsert; encrypted as you type)
just secret-set-all               # enter all secrets in registry order
just secret-get <alias>           # decrypt and print
just secret-edit <alias>          # decrypt into $EDITOR; saving re-encrypts
just secret-remove <alias>        # delete a single ciphertext blob (reminds about the config-layer declaration)
# aliases: userpwd · nix · mongodb · mysql · mysql-root · postgresql · redis

# ── registry: registry CRUD (R27, data-driven; all three layers written in one shot)─────────────────
just secrets-add <alias> <rel-path> [prompt] [transform]
                                  # register a new secret: registry.toml row + template skeleton +
                                  #   shared.nix/tmpl declarations — one command covers all three layers
                                  #   (cachix-token example: see the cachix group below)
just secrets-edit <alias> [prompt] [transform]
                                  # change the registry row's prompt / transform (plain|mkpasswd)
just secrets-remove <alias>       # retire a secret (refuses while ciphertext still exists — run secret-remove first)
just secrets-show <alias>         # full dossier of one secret (row/path/rules/recipients, no decryption)
just secrets-declared             # shared.nix declarations ↔ registry drift view (who is not covered by a verb)
just secrets-db                   # database cache status (row/declaration/ciphertext counts + fingerprint)
just secrets-db-sync              # force-rebuild the cache (after hand-editing registry.toml / shared.nix)

# ── keys: who can decrypt (KEY LAYER)───────────────────────────────────────────
just key-show                     # show the user age public key (safe to share)
just key-destroy                  # destroy the user key file (irreversible)
just key-new-host <alias> [dest]  # generate a host keypair (out-of-repo delivery copy, chmod 400)
just key-show-host <alias> [src]  # show the public key of the host delivery copy
just key-add-host <alias> <age1...> [domain=srv]  # wire the public key into .sops.yaml (incremental)
just key-install-host <alias> [src]  # merge the host identity into this machine's key file (own host, idempotent)
just key-remove <alias>           # revoke a key (accepts the short name lab or the full name host_lab)
just key-rotate-user <age1...>      # rotate the user key (three-step walkthrough)
just key-rotate-host <age1...>      # rotate a host key (four steps: add before removing — no bare window)

# ── rules: policy (RULE LAYER, .sops.yaml = policy source of truth + distribution layer)──────────────
just rules-init                   # rebuild only when missing; refuses on already-evolved files (prevents falling back to a single key)
just rules-reset                  # hard reset to the baseline (host keys + rotations all lost; use with care)
just rules-destroy                # delete .sops.yaml

# ── plaintext template instances (PLAIN LAYER, secrets/plan/**, never committed)─────────────────
just secrets-plan-create          # generate all plaintext template instances (reference before filling in)
just secrets-plan-destroy         # delete all plaintext template instances

# ── Consistency & audit ─────────────────────────────────────────────────────
just secrets-sync                 # sops updatekeys × all (rules ↔ ciphertext alignment)
just secrets-verify               # recipient consistency audit (NO-RULE / DRIFT; same as CI)
just secrets-status               # three-layer audit (key / rule / blob + local identity)
just secrets-destroy-all          # destroy everything sops-related (irreversible)
```

### cachix — the public binary-cache axis (redskaber-nix-config)

```bash
# Cache reachability probe (public information, no token needed) + local substituter wiring + push-half status
just cachix-status               # one screen: URL probe / trusted public key / CI and local push halves

# Token registration flow (preparation stage: register into the secrets system + interactive entry, one command closes the loop)
just cachix-token                # register the cachix-token secret (three layers) + secret-set to enter the value
                                  #   the token comes from https://app.cachix.org/cache/
                                  #   redskaber-nix-config → Auth Tokens (owner-only)

# Local push (token resolution order: CACHIX_AUTH_TOKEN env → cachix-token secret)
just cachix-push /nix/store/...    # push the given store path (cachix binary: $CACHIX_BIN >
                                  #   PATH > nix shell nixpkgs#cachix)
```

### commit — commit-convention deployment

```bash
# Deploy the rules files and hooks for the nix-config repository
just commit-setup

# Install husky hooks into any Git repository (no config files copied; defaults to the current directory)
just commit-husky-install [path=.]

# Copy only the commitlint and commitizen config files into a project (defaults to the current directory)
just commit-project-rules [path=.]

# Deploy the global compatibility rules (optional)
just commit-global-rules
```

### Maintenance

```bash
just dump                        # export the project file tree + concatenated full text to tmp/ (for docs/audits)
```

---
