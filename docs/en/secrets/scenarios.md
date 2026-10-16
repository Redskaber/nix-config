# secrets multi-scenario handbook — the full just workflow

> English mirror of [docs/secrets/scenarios.md](../../secrets/scenarios.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document is the README's "secrets multi-scenario handbook" section (migrated
> verbatim out of the README during the T13.1 layered refactor).
> The nine scenarios cover the complete lifecycle from day one to emergency
> response; the quick-reference table and the hierarchy model are in the
> [README](../../../README.en.md#daily-operations-quick-reference).

> [Quick start](../guides/quickstart.md) is the **linear** zero-to-deploy path;
> this section is the lookup handbook organized **by scenario** — each scenario
> stands on its own, giving the goal, prerequisites, commands, the landing position
> in the state machine, and verification. All scenarios share the same map:
> `just secrets-guide`.

### Quick-reference table (one command, one intent)

| Intent | Command |
| --- | --- |
| What encrypted content do I have / what is missing | `just secrets-list` |
| Register a new secret (all three layers written in one go) | `just secrets-add <alias> <rel-path> [prompt]` |
| Change a registry row's prompt / transform | `just secrets-edit <alias> [prompt] [transform]` |
| Retire a secret (destroy the ciphertext first) | `just secrets-remove <alias>` |
| Declaration ↔ registry drift view | `just secrets-declared` |
| Enter / change a secret | `just secret-set <alias>` |
| View a secret | `just secret-get <alias>` |
| Edit a secret | `just secret-edit <alias>` |
| Enter all of them (in order) | `just secret-set-all` |
| Who can decrypt (key/rule overview) | `just secrets-status` |
| Rules ↔ ciphertext consistency | `just secrets-verify` |
| Align ciphertext after changing rules | `just secrets-sync` |
| Lifecycle map | `just secrets-guide` |

### Scenario 1 — Personal machine day one (from zero, user single key)

**Goal**: a brand-new personal machine, secrets from nothing. **Prerequisites**: Nix + just ready (Quick start Phase 0).

```bash
just init <username>     # shared.nix + hardware.nix + key/rules baseline (generates the user age key)
just secret-set-all      # enter each in turn (encrypted as typed; userpwd needs mkpasswd — see below)
just secrets-verify      # expected: all secret blobs match the .sops.yaml hierarchy
```

```bash
# userpwd goes through mkpasswd sha-512; enter the tool environment once, then do the entry:
nix shell nixpkgs#mkpasswd --command just secret-set-all
```

**Landing**: `USER_ONLY`. **Verification**: `just secrets-list` (everything `set`) +
`just key-show` (record the public key in your password manager; **back up
`~/.config/sops/age/keys.txt` — it is the only decryption key of your personal
domain**). **Commit**: `.sops.yaml` (public keys, safe to commit) and
`secrets/chipr/**` (ciphertext encrypted with your key).

### Scenario 2 — Personal machine also running srv services (one machine, user + host dual key)

**Goal**: a personal machine on the dev-on-demand db profile — the same machine
consuming the user domain and the srv domain. This is the "own host = srv host"
branch: the host private key also lands **on the local machine** (the age identity
file natively holds multiple identities, and `sops-nix`'s `keyFile` already points
there).

```bash
just key-new-host <alias>              # ① generate the host keypair (out-of-repo delivery copy in ~/Downloads)
just init <username> <alias> <age1...> # ② straight to USER+HOST (pass in the public key printed by ①)
just secret-set-all                    # ③ entry (srv-domain blobs get dual recipients)
just key-install-host <alias>          # ④ merge the host identity into this machine's key file
shred -u ~/Downloads/host-<alias>.age  # ⑤ this machine now holds the identity; destroy the delivery copy
```

Already bootstrapped per Scenario 1? Incremental onboarding: `just key-add-host <alias> <age1...>` →
`just secrets-sync` (existing blobs migrate to dual recipients) → `key-install-host`.

**Landing**: `USER+HOST` (the machine holds both identities). **Verification**:
`just secrets-status` (the local identities section should list both keys) +
`just secret-get postgresql` (the srv domain decrypts).

**Why step ④**: in the baseline state the single user key already decrypts the srv
domain; but both paths require the host identity to be in place — after the
**hardening policy** (rotating the srv recipients to host-only) a machine holding
only the user key will be unable to decrypt the srv blobs; the **independent recovery
path** (if the user key is compromised on another machine, this machine's host
identity remains a valid decryptor of the srv domain).

### Scenario 3 — Onboarding a remote server

**Goal**: the server (headless host) can decrypt the srv domain autonomously, no human present.

```bash
just key-new-host <alias>              # ① the server's keypair (generated on your operator machine)
just key-add-host <alias> <age1...>     # ② wire the public key into .sops.yaml (srv domain)
just secrets-sync                      # ③ migrate existing blobs to dual recipients
# ④ delivery: host-<alias>.age → the server's /var/lib/sops-nix/key.txt (chmod 400)
#    (the keyFile target position for the server form; the current module implementation is the own-host home-directory form —
#    see the keyFile landing-spot status note in rotation.md)
#    then shred the delivery copy — the target machine is the sole holder
```

**Landing**: `USER+HOST`. **Verification**: on the server, `sudo sops -d
secrets/chipr/<any-srv>.yaml` (or watch sops-nix activation after deployment).
**Note**: the server does **not need** (and should not have) a user key — it decrypts
only the srv domain.

### Scenario 4 — A second personal machine (importing the existing user key)

**Goal**: the new personal machine decrypts the existing user domain. **Prerequisites**: the Scenario 1 key backup at hand.

```bash
# ① restore the user key (the backed-up keys.txt → the same path on the new machine, chmod 400):
mkdir -p ~/.config/sops/age && cp <backup>/keys.txt ~/.config/sops/age/
chmod 400 ~/.config/sops/age/keys.txt

just init <username>                 # ② baseline (key generation is skipped if the key already exists)
just secrets-verify                  # ③ existing blobs' recipients already consistent
just secret-get nix                  # verify: the user domain decrypts
```

**Note**: `secrets-init` is idempotent — an existing key file is not overwritten (a
private key is unrecoverable, so it is never overwritten). The rules baseline renders with
the machine's **existing** public key (read by `age-keygen -y`).

### Scenario 5 — user key rotation

**Goal**: scheduled rotation / precautionary rotation on suspected exposure.

```bash
age-keygen -o /tmp/new-user.age 2>/dev/null             # ① new keypair (outside the repository)
just key-rotate-user $(age-keygen -y /tmp/new-user.age)
# ② the script prints a three-step guide:
#    1/3 replace the user_* public key in .sops.yaml (the sample gives the exact line)
#    2/3 just secrets-sync        # full re-encryption to the new recipients
#    3/3 commit. Old ciphertext in git history remains decryptable by the old key — accept that exposure or rewrite history
# ③ land the new key on this machine (replace ~/.config/sops/age/keys.txt; back up then destroy the old file)
```

**Landing**: `USER_ONLY`/`USER+HOST` unchanged (the key changes, the layer does not).
**Verification**: `just secrets-verify` + repeat Scenario 4 on other personal
machines.

### Scenario 6 — host key rotation / revocation

**Goal**: server migration, suspected host exposure, decommissioning.

```bash
# rotation (add first, then remove — no bare window):
just key-new-host <new-alias>
just key-rotate-host $(just key-show-host <new-alias>)
#    five-step guide: 0/4 pick the old alias → key-add-host → secrets-sync → key-remove <old> → secrets-sync

# revocation (retire a host):
just key-remove <alias>     # accepts a short name (lab → host_lab) or the full name
just secrets-sync           # the revoked key can never decrypt new ciphertext from here on
```

**Verification**: `just secrets-status` (the keys section no longer lists the
alias) + `secrets-verify`.

### Scenario 7 — Suspected-compromise emergency

1. **Revoke**: `just key-remove <alias>` → `just secrets-sync` (the compromised key
   can never decrypt new blobs again; sops's metadata MAC prevents the old key's
   holder from forging new blobs).
2. **Assess the other domain**: the user domain and the srv domain have isolated
   blast radii ([mechanisms §5 security layer](../architecture/mechanisms.md#5-security-layer--sops--age-layered-management)) —
   which domain was compromised decides the action surface.
3. **Data-layer rotation**: a configuration-layer rotation does not replace the
   data layer — run `ALTER USER ... PASSWORD` once more on the database side.
4. **git history**: old ciphertext remains decryptable in history — accept the
   exposure or rewrite history (the trade-offs of rotation.md §compromise).

### Scenario 8 — Adding a new secret (one command, all three layers written at once)

```bash
# Since R27 the registry is a data file (secrets/registry.toml); the CRUD verbs write all three layers at once:
#   ① the registry.toml row (alias → dotted key → prompt → transform)
#   ② template YAML: docs/tmpl/sops/nixos/core/srv/db/newdb/users/__USERNAME__/password.yaml
#      (leaf key = the last path segment; placeholders __SECRET_VALUE__ / __USERNAME__)
#   ③ the declaration row in shared.nix + docs/tmpl/shared.nix.tmpl (structured insertion, round-trip equivalence preserved)
just secrets-add newdb nixos/core/srv/db/newdb/users/${username}/password "NewDB password"
just secret-set newdb && just secrets-verify
# Rejection face: the path is not covered by any .sops.yaml rule (the plaintext-risk class), alias/key already exists,
#        ${username} as an infix segment (no static naming possible — declare by hand, see the redis row)
```

### Scenario 9 — Destruction / decommissioning

```bash
just secret-remove <alias>     # a single ciphertext (the shared.nix declaration is removed separately — the configuration layer is the truth)
just secrets-plan-destroy      # all plaintext reference instances
just rules-destroy             # .sops.yaml
just key-destroy               # this machine's user key file (irreversible! the blobs stay in the repository)
just secrets-destroy-all       # all of the above (plaintext instances + ciphertext + rules + key files)
```

> Destroying the key file does not affect the ciphertext in the repository (they
> wait for **some** legitimate private key to come decrypt them); before destroying
> ciphertext, confirm that the declaration in shared.nix has also been retired —
> otherwise eval honestly reports "declared but not provided".

---
