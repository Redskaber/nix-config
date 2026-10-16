# Quick Start — The Full Guided Path from Zero to Deployment (just-driven)

> English mirror of [docs/guides/quickstart.md](../../guides/quickstart.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document is the full version of the README's "Quick Start" section
> (moved out of the README verbatim during the T13.1 layered refactoring).
> Six phases, followable from bare metal; the README keeps a quick overview
> of the first-deployment main path.

> Six phases, every step a just verb or an explicit nix command; whenever you
> are unsure at any step, go back to the corresponding guide (`just
> secrets-guide` / `just --list`). This section is the complete path "starting
> from zero" — followable from bare metal; machines that already exist can
> enter at a middle phase.

### Phase 0 — Bare metal → Nix + just ready

**NixOS** (Nix built in; the LiveISO ships it too): skip to Phase 1.

**Non-NixOS Linux / macOS / WSL2** (home-manager layer only):

```bash
# Install Nix (the Determinate Systems installer, with flakes support out of the box)
curl -L https://install.determinate.systems/nix | sh -s -- install

# Enable flakes (the official installer and existing installs need it turned on manually)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes pipe-operators" >> ~/.config/nix/nix.conf
```

**Making just available** (the entry to every operation plane of this
repository; not installed globally — entered ephemerally):

```bash
nix shell nixpkgs#just nixpkgs#git      # or: nix-shell -p just git
```

> From here on, all commands are executed at the repository root (that is
> where `just` anchors its ROOT).

### Phase 1 — Clone + the policy and key baseline

> **Note:** After the first NixOS build, directories under non-`/` mount
> points come under NixOS management — put the configuration in a suitable
> path. If the first build is not done from outside the system's own
> directories, the remaining ~/* will be wiped out (because the user
> identity has not been created yet, among other reasons). (nixos itself)
>
> Subsequent builds do not have this problem

```bash
git clone https://github.com/Redskaber/nix-config /etc/nix-config
cd /etc/nix-config
```

**Personal machine** (user key, single-key baseline):

```bash
just init <username>
#   = shared-generate (policy truth in shared.nix)
#   + hardware-generate (hosts/<hostname>/hardware.nix hardware probing)
#   + secrets-init (directory + user age key + .sops.yaml baseline)
```

**Server machine** (user + host dual-key direct bootstrap — two steps
replacing three):

```bash
just key-new-host <alias>                # ① generate the host keypair (out-of-repo delivery copy, chmod 400)
just init <username> <alias> <age1...>   # ② straight to USER+HOST (dual recipients in the srv domain)
# ③ deliver the copy to the target machine's /var/lib/sops-nix/key.txt (chmod 400), then shred
```

> Already bootstrapped as a personal machine and want to bring a host key in
> incrementally? Use `just key-add-host` + `secrets-sync` (see the four-step
> flow in `just secrets-guide`).

### Phase 2 — secrets ready

```bash
just secrets-plan-create                # optional: generate the plaintext template reference (consult it before filling in)

nix shell nixpkgs#mkpasswd --command just secret-set-all
# interactive entry, one item at a time (encrypted as typed, plaintext never hits disk); or individually as needed:
#   just secret-set userpwd             # user system password (mkpasswd sha-512)
#   just secret-set nix                 # GitHub access token
#   just secret-set mongodb             # ...

just secrets-verify                     # recipient-consistency audit (expect all green; if red, fix per the hints)
just secrets-status                     # three-layer status overview (key / rule / blob + this machine's identity)
```

> **Personal machine that also runs srv services** (dev-on-demand db
> profile)? After bootstrapping with the direct dual key in Phase 1, land
> the host identity on this machine as well: `just key-install-host
> <alias>` — the single user key of the baseline state already suffices,
> but both the hardened srv policy (host-only) and this machine's independent
> recovery path require it to be in place (see rotation.md §2b "own host =
> srv host" for details).

### Phase 3 — First deployment

```bash
just hosts-list                  # confirm the host key (data-driven from the hosts/ directory)
```

**A. Brand-new NixOS machine (installed from LiveISO)**:

```bash
# after partitioning + mounting (/ and /boot), generate the hardware config in the target environment and install:
sudo nixos-install --flake /etc/nix-config#<host>
```

**B. Existing NixOS system (take over / switch to this configuration)**:

```bash
just nixos-switch <host>         # = sudo nixos-rebuild switch --flake .#<host>
```

**C. Non-NixOS platforms (home-manager layer only)**:

```bash
just home-switch <host>          # → <username>@<host> (e.g. just home-switch wsl)
# macOS: darwin-rebuild switch --flake .#<host>
```

### Phase 4 — Verification and rollback

```bash
just secrets-status              # secrets three-layer health
nixos-rebuild list-generations   # generation list (one generation per switch)
sudo nixos-rebuild rollback      # single command back to the previous generation
just nixos-test <host>           # experimental switch (no boot entry written; discarded on reboot)
just nixos-boot <host>           # set only the next generation's boot, without activating (T10.2 — a safer deployment face for remote/rollback flavors)
```

### Phase 5 — day-2 quick reference (after going live)

```bash
# routine update (sops-nix stays pinned, guarding the decryption chain against accidental breakage)
just flake-update-not-sops && just nixos-switch <host>

# secrets lifecycle (map: just secrets-guide / docs: docs/secrets/rotation.md)
just secrets-verify              # the same audit CI runs
just key-rotate-user <age1...>   # user key rotation (three-step guided)
just key-rotate-host <age1...>   # host key rotation (add new → re-encrypt → revoke old)

# onboarding a new machine = mkdir hosts/<name> + two files (zero flake changes)
# declaring a new secret = three layers (shared.nix.tmpl / template YAML / 4-line recipe; see the extending guide)
```

### Development environments

```bash
# one-off entry (no profile saved)
nix develop .#rust
nix develop .#python
nix develop .#python-machine

# persistent profile (available offline; quick re-entry next time)
just devenv-create rust
just devenv-create-from python machine

# enter an existing profile
just devenv-use rust
just devenv-use-from python machine

# automatic activation via direnv (recommended workflow)
echo "use flake github:Redskaber/nix-config#python-machine" > .envrc
direnv allow
```

---
