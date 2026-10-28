# CI/CD Deep Manual — Rationale, Local Pre-flight, and the Deployment Flow

> English mirror of [docs/ci/pipeline.md](../../ci/pipeline.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document houses the deep part of the README's "CI/CD complete execution
> flow" section (moved out during the T13.1 layered refactoring): why CI/CD is
> needed, the local pre-flight checklist, the deployment workflow, generation
> management and rollback, and automated updates. For the pipeline panorama
> and the cache strategy, see [the README](../../../README.en.md#cicd-complete-execution-flow).

### Why a Nix configuration needs CI/CD

Every change to nix-config is equivalent to declaring a new system state. The
core value of CI:

1. **Evaluation checks** — catch Nix syntax/type errors (failing earlier than
   nixos-rebuild does)
2. **Deep evaluation** — face-sharded enforcement (T15.1): the api envelope +
   per-host toplevel drvPath + misc checks + completeness reconciliation
   (all 109 checks must be owned by a plane or the misc inventory; the
   single-process `nix flake check` has been retired because of its
   memory-accumulation floor)
3. **Secret integrity + supply chain** — verify that the encrypted files are
   structurally correct and that `secrets/plan/` is not committed; every
   GitHub Actions reference is pinned to a 40-hex commit SHA (the T16.1
   machine contract: an unpinned reference fails-fast red in the Security
   Audit leg, and a tampered upstream tag cannot affect this pipeline)
4. **Test coverage** — 103 tests covering the smoke/nixos/home/lib/integration/nmt
   planes
5. **Automated updates** — every Sunday, automatically update the flake
   inputs and open a PR

---

### Local pre-flight checklist (before push)

```bash
# 1. Static checks
nix run nixpkgs#statix -- check .

# 2. Structural validation (no builds, no sopsFile triggered)
nix eval .#nixosConfigurations --apply builtins.attrNames --json
nix eval .#homeConfigurations  --apply builtins.attrNames --json
nix eval .#checks.x86_64-linux --apply builtins.attrNames --json

# 3. nmt plane (fastest, < 30s, no QEMU)
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" --no-link

# 4. devShell dry-run (per member, enumeration via attrNames — T18.1)
for s in $(nix eval .#devShells.x86_64-linux --apply builtins.attrNames --json \
  | python3 -c 'import json,sys; print(" ".join(json.load(sys.stdin)))'); do
  nix build ".#devShells.x86_64-linux.\"$s\"" --dry-run --no-link || exit 1
done

# 5. Secret file validation
find secrets/chipr -name "*.yaml" | xargs grep -L "^sops:" 2>/dev/null \
  && echo "ERROR: plaintext files found" || echo "OK"
```

### Deployment workflow

```
Dev machine (local)                        Production machine (NixOS)
    │                                      │
    ├── edit *.nix                         │
    ├── nix eval ... (structure check)     │
    ├── git push → CI (GitHub Actions)     │
    │       └── 7 stage passes             │
    │                                      │
    └── [CI Pass]                          │
        │   cd /etc/nix-config             │
        │   git pull                       │
        │                                  │
        │   just nixos-switch nixos        │  # => sudo nixos-rebuild switch --flake .#nixos
        │                                  │
        │   just home-switch nixos         │  # => home-manager switch --flake .#kilig@nixos
        │                                  │
        └── systemctl status sops-*        │
            just secret-get mongodb        │
```

### Generation management and rollback

```bash
# List available system generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Roll back to the previous generation
sudo nixos-rebuild switch --rollback

# Roll back to a specific generation
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation <N>
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### Automated updates

Every Sunday at UTC 03:00, `.github/workflows/update-flake.yml` automatically:

1. Runs `nix flake update` to refresh all inputs; afterwards nixpkgs is
   re-pinned to the `nixos-26.05` **channel-snapshot** rev (the
   git-revision published by `channels.nixos.org` — fully built by Hydra and
   wholly substitutable from cache.nixos.org; see incident adjudication #2
   below)
2. Generates a `flake.lock` diff summary
3. Opens a PR (branch: `automation/update-flake-inputs`, label:
   `dependencies automated`)
