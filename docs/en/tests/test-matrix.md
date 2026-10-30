# NixOS Config — Test Matrix

> English mirror of [docs/tests/test-matrix.md](../../tests/test-matrix.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> `docs/tests/test-matrix.md`
> Updated: 2026-10-10

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Test-Plane Division](#2-test-plane-division)
3. [The Complete Test Matrix](#3-the-complete-test-matrix)
4. [Directory Structure](#4-directory-structure)
5. [Running Guide](#5-running-guide)
6. [Design Principles and Constraints](#6-design-principles-and-constraints)
7. [Extending with New Tests](#7-extending-with-new-tests)
8. [CI Integration](#8-ci-integration)

---

## 1. Architecture Overview

```
tests/
├── default.nix              ← unified registry: every check of Plane 0–5
├── test_calc.nix            ← the Smoke baseline
├── nixos/                   ← NixOS-Plane (QEMU VM)
├── home/                    ← HM-Plane   (QEMU VM + packages)
├── lib/                     ← Lib-Plane  (pure Nix eval, minimal QEMU)
├── integration/             ← Integration-Plane (NixOS + HM)
└── nmt/
    ├── default.nix          ← Plane 5 runner (buildHomeManagerTest impl)
    └── home/...             ← test files (lib.nmt.buildHomeManagerTest)
```

### The nmt Acquisition Mechanism and Call Chain

```
flake.nix
  nmt.url   = "github:Redskaber/nmt"   ← sourcehut mirror (flake = false)
  nmt.flake = false                     ← no flake.nix, the raw store path

tests/nmt/default.nix
  nmtSrc  = inputs.nmt                  ← store path
  hmPath  = inputs.home-manager         ← HM modules + stdlib-extended lib
  hmLib   = import "${hmPath}/modules/lib/stdlib-extended.nix" pkgs.lib
  hmModules = import "${hmPath}/modules/modules.nix" { lib; pkgs; check=false; }

  buildHomeManagerTest testSpec
    → import nmtSrc {
        lib            = hmLib;
        pkgs           = scrubbedPkgs;   ← derivations → "@pkg-name@"
        modules        = hmModules ++ [baseModule] ++ testSpec.modules;
        testedAttrPath = ["home" "activationPackage"];
        tests          = { <name> = { nmt.script = ...; }; };
      }
    → result.build.<name>               ← derivation for flake check
```

### Why Not sourcehut / fetchTarball

| Approach                                 | Result                                        |
| ---------------------------------------- | --------------------------------------------- |
| `sourcehut:~rycee/nmt` flake input       | ❌ HTTP 403 — go-away bot-protection           |
| `fetchTarball "https://git.sr.ht/..."`   | ❌ HTTP 403 — the same blocking policy         |
| `inputs.home-manager.lib.hm.nmt`         | ❌ release-25.11 does not export this attribute |
| `github:Redskaber/nmt` + `flake=false`   | ✅ GitHub reachable, store path referenced directly |

### `buildHomeManagerTest` Is Not a Native nmt API

The real signature of nmt's `default.nix`:

```nix
{ modules, testedAttrPath, tests, pkgs, lib ? pkgs.lib }
→ { build; run; report; list }
```

`buildHomeManagerTest` is home-manager's own test wrapper — it **does not exist in nmt itself**.
`tests/nmt/default.nix` fully implements this wrapper, so all existing test files work unmodified.

---

## 2. Test-Plane Division

| Plane             | Prefix         | runner                   | VM?        | Focus                            | Typical duration |
| ----------------- | -------------- | ------------------------ | ---------- | -------------------------------- | ---------------- |
| **Smoke**         | `test_`        | `runNixOSTest`           | QEMU       | basic system integrity           | ~1 min           |
| **NixOS-Plane**   | `nixos_`       | `runNixOSTest`           | QEMU       | `nixos/*` modules + system services | 2–10 min      |
| **HM-Plane**      | `home_`        | `runNixOSTest`           | QEMU       | `home/*` package installs + runtime behavior | 2–8 min |
| **Lib-Plane**     | `lib_`         | `runNixOSTest` (minimal) | QEMU 256MB | `lib/shared` pure expressions    | <1 min           |
| **Integration**   | `integration_` | `runNixOSTest`           | QEMU full  | NixOS + HM joint activation      | 5–15 min         |
| **nmt-Plane**     | `nmt_`         | `buildHomeManagerTest`   | **no VM**  | HM dotfile content assertions    | <10 s            |

### nmt vs HM-Plane: Complementary

Every HM tool that owns a dotfile gets two-layer coverage:

```
home/core/exp/sys/base/fd.nix
  ├─ nmt_home_core_exp_sys_base_fd     dotfile content (pure eval, <10s)
  │    .config/fd/ignore: .git/ / *.bak entries
  └─ home_core_exp_sys_base_fd         runtime behavior (QEMU VM, ~2min)
       fd --version, fd finds files by pattern

home/core/exp/sys/base/git.nix
  ├─ nmt_home_core_base_git            dotfile content (pure eval, <10s)
  │    .config/git/config: [user] name/email/branch/[delta]
  └─ home_core_exp_sys_base_git        runtime behavior (QEMU VM, ~2min)
       git --version, git init + commit + log
```

### nmt Suitability Decision Table

| Condition                                                            | Suitable for nmt-Plane? |
| -------------------------------------------------------------------- | ----------------------- |
| The tool generates its config file through HM `programs.*` options  | ✅ suitable             |
| The config file is plain text (not `pkgs.formats.*`)                  | ✅ content assertions possible |
| The config file goes through `pkgs.formats.toml/json`                | ⚠️ exists-only assertions |
| The tool is only installed via `home.packages`, no HM config         | ❌ not suitable, use Plane 2 |
| Needs GUI / Wayland / GPU support                                    | ❌ not suitable, use Plane 2 |
| Needs service runtime verification                                   | ❌ not suitable, use Plane 1 |

---

## 3. The Complete Test Matrix

### 3.0 Smoke (1 test)

| check       | File            | What it verifies        |
| ----------- | --------------- | ----------------------- |
| `test_calc` | `test_calc.nix` | echo, 1+1=2, screenshot |

### 3.1 NixOS-Plane (30 tests)

| check                                                        | What it verifies                                           |
| ------------------------------------------------------------ | ----------------------------------------------------------- |
| `nixos_core_base_{boot,i18n,network,nix,sound,user}`         | systemd-boot / locale / networkd / flakes / pipewire / user |
| `nixos_core_base_{i18n_source,i18n_samesource}`              | T1.2 production-tree import (same-source guard) |
| `nixos_core_base_{wsl,portal}`                                | T7.1 WSL form evaluation / T7.2 portal capability-gate dual laws |
| `nixos_core_base_sound_gate`                                   | T10.1 sound policy-axis gate dual laws (full pipewire stack / none wholesale subtraction) |
| `nixos_core_base_impermanence`                                | T5.14 rollback recipe / unit ordering / device gate / laziness law |
| `nixos_core_drive_{amd,intel,nvidia}`                        | GPU driver toolchain                                        |
| `nixos_core_sec_{pam,polkit,secret_cmd_age,secret_cmd_sops}` | PAM / polkit / age / sops                                   |
| `nixos_core_srv_db_{mongodb,mysql,postgresql,redis}`         | service active + DB ops                                     |
| `nixos_core_srv_hardware_{bluetooth,printing}`               | bluetoothd / cups                                           |
| `nixos_core_srv_log_logrotate`                               | binary + timer                                              |
| `nixos_core_srv_monitor_policy`                               | monitoring policy (export-modules pattern) |
| `nixos_core_srv_security_{ssh,keyring}`                      | sshd :22 / gnome-keyring                                    |
| `nixos_export_modules`                                        | T5.3 export/ module semantic evaluation        |

> Total: base(11 = 6 + i18n_source + samesource + wsl + portal + sound_gate) + impermanence(1) + drive(3) + sec(4) + db(4) + monitor(1) + hardware(2) + log(1) + security(2) + export(1) = **30**

### 3.2 HM-Plane (42 tests)

| check                                                                                           | What it verifies                           |
| ----------------------------------------------------------------------------------------------- | -------------------------------- |
| `home_core_base_{fonts,i18n}`                                                                   | fc-list / fcitx5                 |
| `home_core_base_i18n_source`                                                                    | T1.2 production-tree import (same-source guard) |
| `home_core_base_nix`                                                                            | user-domain nix plane (dual-state gating: wsl-class rendering / nixos-class silence — the nix.conf priority chain; real const identity end-to-end + checkPhase build-time syntax validation) |
| `home_core_exp_app_editor_nvim`                                                                 | nvim headless Lua                |
| `home_core_exp_sys_base_{atuin,bat,direnv,eza,fd,fzf,git,jq,ripgrep,starship,tmux,yazi,zoxide}` | binary + version + workflow      |
| `home_core_exp_sys_base_{fzf,git,starship}_source`                                               | T1.2 production-tree import (policy wiring)   |
| `home_core_exp_sys_shell_{zsh,fish}`                                                            | binary / compinit / abbr         |
| `home_core_exp_sys_shell_zsh_source`                                                             | T1.2 production-tree import (shell contract)|
| `home_core_exp_sys_{monitor,media,fs}`                                                          | btop+htop / mpv+ffmpeg / duf+tar |
| `home_core_sec`                                                                                 | module parses                    |
| `home_core_srv_notify_mako`                                                                     | mako + makoctl                   |
| `home_core_srv_security_gnupg`                                                                  | gpg + gpg-agent                  |
| `home_env_dev_{c,cpp,rust,go,python,typescript,java,lua,zig,nix,re}`                            | toolchain binary + hello-world   |
| `home_export_modules`                                                                          | T5.3 export/ module semantic evaluation        |

> Total: base(3) + i18n_source(1) + editor(1) + sys/base(13 + 3 source) + shell(2 + 1 source) + sys/monitor+media+fs(3) + sec(1) + notify(1) + security(1) + env/dev(11) + export(1) = **42**

### 3.3 Lib-Plane (13 tests)

| check | What it verifies |
| ------------------------------------ | --------------------------------- |
| `lib_shared_shared_{enum,fn,schema}` | enum semantics / fn logic / schema merge |
| `lib_shared_targets` | source-of-truth census (T19.1) + naming census (Law G, R7): hosts/ × classifier caps — a bare-metal NixOS host carries exactly one source of truth, host-held forms carry zero sources, and a double source is an immediate red (the failure mode of migrating itself is exactly Law A); the naming faces are read through the real target factory, attrNames only — the legacy alias never shadows a real host directory, the three faces key exactly by inventory (nixos = nixosHosts + alias · home = "<user>@<host>" · darwin = darwinHosts), no face name carries an arch tag (arch is a pipeline value, never an address), and hostName answers its directory on every host |
| `lib_shared_deploy` | deployment-plane census (T21.1): the T20.1 simulation upgraded into a pinned test — Law D: no lying deployment facts (no deploy.nix on non-nixosHosts)+ launch coverage precise in both directions (colmenaHive nodes == the classifier's nixosHosts, zero hardcoded member tables)+ the user gate alive (targetUser = the policy user, ssh forbids root and forbids password — empty or root is a death gate); an attrNames-only lazy chain (never evaluates a single whole tree, drvPath equivalence is left to the CI gate) |
| `lib_shared_overlays` | overlay locality census (T24.2, pinned by the run 38171937689 re-run adjudication): the canary substituted-instance method — patches are applied to marked stub instances, and every patched member (cutter_patched/openldap/xdg-desktop-portal) must carry the canary mark (meta.description survives through overrideAttrs); taking a package from any external handle loses the mark and goes red — the overlay contract: patch exactly the one you changed, `prev`/`final` are the fixpoint of the very instance being applied |
| `lib_shared_lang_version` | nix-types version contract (T25.2, the downstream assertion landed): rev answers where (the flake.nix 40-hex pin point), version answers what (this test's expected) — `inputs.nix-types.lib.version == "3.6.0"`, a bump = a deliberate two-file decision, one-sided drift is a single-line red (the diagnostic reports all three parties — lock rev / expected / observed — plus two-file reconciliation guidance; verified by mutation checks) |
| `lib_shared_orc` | orc wallust copy-emitter consumption contract (T28): a single `homeManagerConfiguration` evaluated through the production modules, covering all seven stations (the mechanisms.md §6 inventory) — dag entry exists + writeBoundary post-order + the full `run cp --remove-destination <tree>/<rel> "$HOME/<dest>/<rel>"` line (source-tree carries-the-file + destination key + flags, three in one — an upstream file move / include rot / a destPrefix typo, any one of these goes red) + the `run chmod u+w` writable bit; the first run caught the swaync station's empty activation (the swaync-config tree has no placeholder — the dead-silent failure mode of a zero-match include), fixed with a module-side synthetic entry + the companion-repo patch archived in docs/feedback/; the eval-time adjudication uses plain substring search (lib.hasInfix internally forbids builtins.match patterns containing store paths — a language-level restriction worked around) |
| `lib_shared_orc_guard` | orc include-intent guard consumption contract (T30, No. 100): the third-generation tool-library loop closed out — the orc pinned by the lock must carry the T29 guard (05c658f). The real `shared.orc` (the production handle) × the real swaync-config tree, four assertions: a non-empty include with zero matches must explode at eval time (`tryEval success = false` — fleet-scale proof of death for the T28 silent class) + zero tax on the normal path (the copy strategy yields an activation + empty homeFiles) + the `allowEmpty = true` escape gate (explicit waiver yields empty without exploding) + `include = []` fully accepted (census is not a filter). Same shape as the No. 97 version contract: the lock answers WHERE, the test answers WHAT, one-sided drift is a single-line red |
| `lib_shared_pdshell` | pdshell loader consumption contract (T31, No. 101 — the four-library family closed out): the real `shared.pdshells` (the production handle) × the same arguments flake.nix passes, five groups of assertions: **census** (the exact 27-member set — membership, not the docs-ssot count; the only tripwire against `_`-prefix silent exclusion and upstream naming-rule drift) + **face** (`dev-shell-<member>` name injection) + **combinFrom** (the root default's own buildInputs is empty; all merged inputs must arrive via the contributions of the sixteen language defaults — four probes, one language each) + **lifecycle** (section markers + inherited-before-own + FINAL SHELL OVERRIDE exporting the identity-axis shell) + **NamedFile isolation** (renpy ships its own engine, leaking no sibling or cross-scope inputs); double red on mutation (silent rename / `_` prefix); T31r ground truth re-recorded after the sandbox reset |

### 3.4 Integration-Plane (1 test)

| check                       | What it verifies                                            |
| --------------------------- | ------------------------------------------------- |
| `integration_hm_activation` | HM NixOS module wiring, user home, zsh/git/direnv |

### 3.5 nmt-Plane (16 tests, zero-VM)

| check                               | File                                    | What it verifies                                     | Assertion type        |
| ----------------------------------- | --------------------------------------- | ---------------------------------------------------- | --------------------- |
| `nmt_home_core_exp_sys_base_git`            | `nmt/home/core/exp/sys/base/git.nix`            | .config/git/config: user/branch/delta        | exists+contains       |
| `nmt_home_core_exp_sys_base_starship`       | `nmt/home/core/exp/sys/base/starship.nix`       | .config/starship.toml: exists (scrubbed)     | exists                |
| `nmt_home_core_exp_sys_base_direnv`        | `nmt/home/core/exp/sys/base/direnv.nix`        | .config/direnv/direnvrc: nix-direnv          | exists+contains       |
| `nmt_home_core_exp_sys_base_atuin`          | `nmt/home/core/exp/sys/base/atuin.nix`          | .config/atuin/config.toml: exists (scrubbed) | exists                |
| `nmt_home_core_exp_sys_base_zoxide`         | `nmt/home/core/exp/sys/base/zoxide.nix`         | .zshrc: zoxide init                          | contains              |
| `nmt_home_core_exp_sys_base_tmux`           | `nmt/home/core/exp/sys/base/tmux.nix`           | .config/tmux/tmux.conf: history-limit        | exists+contains       |
| `nmt_home_core_exp_sys_base_bat`            | `nmt/home/core/exp/sys/base/bat.nix`            | .config/bat/config: --theme/--pager          | exists+contains       |
| `nmt_home_core_exp_sys_base_fd`     | `nmt/home/core/exp/sys/base/fd.nix`     | .config/fd/ignore: .git/ / \*.bak            | exists+contains       |
| `nmt_home_core_exp_sys_base_fzf`    | `nmt/home/core/exp/sys/base/fzf.nix`    | .zshrc: fzf sourced / layout=reverse         | exists+regex+contains |
| `nmt_home_core_exp_sys_base_ripgrep` | `nmt/home/core/exp/sys/base/ripgrep.nix` | .config/ripgrep/ripgreprc: --smart-case (leading-dash needle, T27.2's consumption-grade regression proof of the fork `--` guard) | exists+contains       |
| `nmt_home_core_exp_sys_base_yazi`   | `nmt/home/core/exp/sys/base/yazi.nix`   | yazi.toml exists / init.lua: full-border     | exists+contains       |
| `nmt_home_core_exp_sys_shell_zsh`   | `nmt/home/core/exp/sys/shell/zsh.nix`   | .zshrc: compinit/HISTSIZE                    | exists+contains       |
| `nmt_home_core_exp_sys_shell_fish`  | `nmt/home/core/exp/sys/shell/fish.nix`  | config.fish: greeting/abbr                   | exists+contains       |
| `nmt_home_core_exp_app_editor_nvim` | `nmt/home/core/exp/app/editor/nvim.nix` | .config/nvim/init-test.vim: nocompatible     | exists+contains       |
| `nmt_home_core_srv_security_gnupg`  | `nmt/home/core/srv/security/gnupg.nix`  | .gnupg/gpg.conf: use-agent                   | exists+contains       |
| `nmt_home_core_srv_notify_mako`     | `nmt/home/core/srv/notify/mako.nix`     | .config/mako/config: font/colors             | exists+contains       |

> Total: exp/sys/base(11) + shell(2) + app/editor(1) + srv/security(1) + srv/notify(1) = **16** (the pre-T27.2 table's 7 rows carried stale check names/paths (`nmt_home_core_base_*`) — this round aligned them with the registry's real names; docs-ssot anchors only the count and let the name/path drift pass)

---

## 4. Directory Structure

```
tests/
├── default.nix
├── test_calc.nix
├── nixos/core/{base,drive,sec,srv}/...
├── home/
│   ├── core/
│   │   ├── base/{fonts,i18n,i18n-source}.nix
│   │   ├── exp/
│   │   │   ├── app/editor/nvim.nix
│   │   │   └── sys/
│   │   │       ├── base/{atuin,bat,direnv,eza,fd,fzf,git,jq,ripgrep,starship,tmux,yazi,zoxide}.nix
│   │   │       ├── fs/default.nix
│   │   │       ├── media/default.nix
│   │   │       ├── monitor/default.nix
│   │   │       └── shell/{fish,zsh}.nix
│   │   ├── sec/default.nix
│   │   └── srv/
│   │       ├── notify/mako.nix
│   │       └── security/gnupg.nix
│   └── env/dev/{c,cpp,go,java,lua,nix,python,re,rust,typescript,zig}/default.nix
├── lib/shared/lang/{enum,fn,schema}.nix
├── integration/hm_activation.nix
└── nmt/
    ├── default.nix                        ← buildHomeManagerTest impl + registry
    └── home/
        └── core/
            ├── exp/
            │   ├── app/editor/nvim.nix
            │   └── sys/
            │       ├── base/{fd,fzf,yazi}.nix
            │       └── shell/{zsh,fish}.nix
            ├── base/{atuin,bat,direnv,git,starship,tmux,zoxide}.nix  (via nmt/ structure)
            └── srv/
                ├── notify/mako.nix
                └── security/gnupg.nix
```

> **Note:** the 7 tool files under `base/` in nmt/ actually live under `nmt/home/core/exp/sys/base/` (
> atuin/bat/direnv/git/starship/tmux/zoxide), the path symmetric with `home/core/exp/sys/base/`.

---

## 5. Running Guide

```bash
# everything (KVM required locally)
nix flake check

# nmt only — the fastest, no QEMU, no KVM
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json \
  | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" -L --no-link

# a single nmt test
nix build .#checks.x86_64-linux.nmt_home_core_base_git -L
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_fd -L
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_fzf -L
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_yazi -L
nix build .#checks.x86_64-linux.nmt_home_core_exp_app_editor_nvim -L

# NixOS plane (KVM required)
nix build .#checks.x86_64-linux.nixos_core_srv_db_postgresql -L
nix build .#checks.x86_64-linux.nixos_core_base_user -L

# HM plane, a single one
nix build .#checks.x86_64-linux.home_core_exp_sys_base_fd -L
nix build .#checks.x86_64-linux.home_env_dev_rust -L

# Integration
nix build .#checks.x86_64-linux.integration_hm_activation -L

# filter by plane
SYS=x86_64-linux
for PREFIX in nixos_ home_ lib_ integration_ test_; do
  nix eval ".#checks.${SYS}" \
    --apply "cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 ${#PREFIX} n == \"${PREFIX}\") cs)" \
    --json \
    | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]"
done
```

---

## 6. Design Principles and Constraints

### nmt Integration Constraints

| Constraint                                                           | Reason                                        |
| -------------------------------------------------------------------- | --------------------------------------------- |
| `flake = false` on `inputs.nmt`                                     | the nmt repo has no flake.nix                  |
| Mirror: `github:Redskaber/nmt`                                       | sourcehut returns 403 to all Nix fetcher UAs  |
| `buildHomeManagerTest` implemented in `tests/nmt/default.nix`        | nmt does not provide this function natively  |
| scrubDerivations replaces all outPaths                              | prevents nmt eval from triggering real package builds |
| hmModules from `inputs.home-manager`                                | guarantees HM option semantics match production |

### The Relationship Between pkgs.formats.\* and scrubbing

| HM config path                              | How the file is generated      | Assertable content |
| ------------------------------------------- | ------------------------------ | ------------------ |
| `programs.git` (plain text)                 | `home.file` text write         | exists + contains  |
| `programs.tmux` (plain text)                | `home.file` text write         | exists + contains  |
| `programs.starship` (formats.toml)          | derivation → scrubbed          | exists only        |
| `programs.atuin` (formats.toml)             | derivation → scrubbed          | exists only        |
| `programs.fd.ignores` (plain text)          | text written directly          | exists + contains  |
| `programs.ripgrep.arguments` (plain text)   | text written directly          | exists + contains  |
| `programs.fzf` (shell init text)            | shell init injection           | exists + contains  |
| `programs.jq.colors` (plain text)           | text written directly          | exists + contains  |
| `programs.yazi.initLua` (plain text)         | home.file write              | exists + contains  |
| `programs.yazi.settings` (formats.toml)     | derivation → scrubbed          | exists only        |

### assertFileContains Needle Constraints

```
# ❌ WRONG — needle starts with "--", grep treats it as flag
contains = [ "--smart-case" ];

# ✅ CORRECT — strip leading "--"
contains = [ "smart-case" ];

# ✅ CORRECT — use regex key for pattern matching
regex = "smart.case";
```

### Plane-Isolation Constraints

| Constraint | Reason |
| ---------------------------------- | ---------------------------------------------------- |
| NixOS-Plane does not import HM modules | a clear system-layer/user-layer boundary, preventing cross-dependencies |
| HM-Plane does not import NixOS system config | same as above |
| secrets/sops do not enter unit tests | the test environment has no real age keys |
| nmt test-file paths mirror source paths | path semantics: test path = source path |

### test File Format

```nix
# tests/nmt/home/**/*.nix — the fixed interface, no changes needed
{ lib, ... }:
lib.nmt.buildHomeManagerTest {
  description = "tool: ...";
  modules = [{ home.username = "testuser"; ... }];
  tests = {
    "tool: file exists"   = { path = ".config/..."; exists   = true; };
    "tool: value written" = { path = ".config/..."; contains = [ "..." ]; };
    "tool: regex match"   = { path = ".config/..."; regex    = "pattern"; };
  };
}
```

---

## 7. Extending with New Tests

### Adding a New nmt-Plane Test (checklist)

```nix
# 1. Decide: does the tool generate an assertable dotfile?
#    - programs.foo → generates ~/.config/foo/config (plain text)? → YES
#    - home.packages = [ foo ]? → NO, use Plane 2

# 2. create the test file (the path mirrors the source path)
# tests/nmt/home/core/exp/sys/base/new-tool.nix
{ lib, ... }:
lib.nmt.buildHomeManagerTest {
  description = "new-tool: config written";
  modules = [{
    home = { username = "testuser"; homeDirectory = "/home/testuser"; stateVersion = "25.11"; };
    programs.new-tool = {
      enable = true;
      someOption = "value";
    };
  }];
  tests = {
    "new-tool: config exists"   = { path = ".config/new-tool/config"; exists = true; };
    "new-tool: setting written" = { path = ".config/new-tool/config"; contains = [ "value" ]; };
  };
}

# 3. register it in tests/nmt/default.nix
nmt_home_core_exp_sys_base_new_tool = buildTest ./home/core/exp/sys/base/new-tool.nix;

# 4. tests/default.nix needs no modification — auto-merged (import ./nmt { ... })

# 5. verify
nix build .#checks.x86_64-linux.nmt_home_core_exp_sys_base_new_tool -L
```

### Troubleshooting scrubbing Issues

```
Error: "@some-pkg@/bin/some-pkg: No such file or directory"
Cause: the package was replaced by scrubDerivations, add it to the whitelist
Fix: add to the whitelist in tests/nmt/default.nix:
      inherit (pkgs) some-pkg;
```

### Adding a New NixOS-Plane Test

```nix
# tests/nixos/core/srv/db/newdb.nix
{ ... }:
{
  name = "nixos_core_srv_db_newdb";
  nodes.machine = { pkgs, shared, ... }: {
    imports = [ shared.nixosModules.default ];
    nixos.core.srv.db.newdb.enable = true;
  };
  testScript = ''
    machine.wait_for_unit("newdb.service")
    machine.succeed("newdb --version")
  '';
}

# register it in tests/default.nix
nixos_core_srv_db_newdb = nixosTest ./nixos/core/srv/db/newdb.nix;
```

### Adding a New HM-Plane Test

```nix
# tests/home/core/exp/sys/base/new-tool.nix
{ pkgs, shared, ... }:
{
  name = "home_core_exp_sys_base_new_tool";
  nodes.machine = { ... }: {
    home-manager.users.testuser = { pkgs, ... }: {
      programs.new-tool.enable = true;
    };
  };
  testScript = ''
    machine.wait_for_unit("home-manager-testuser.service")
    machine.succeed("new-tool --version")
  '';
}

# register it in tests/default.nix
home_core_exp_sys_base_new_tool = nixosTest ./home/core/exp/sys/base/new-tool.nix;
```

---

## 8. CI Integration

The CI pipeline (`.github/workflows/ci.yml`) maps the test planes to independent jobs, maximizing parallelism and feedback speed:

```
STAGE 1: lint              [always]      static analysis + shallow eval (no builds)
    │
    ├─► STAGE 2: nmt-plane [parallel]   pure Nix eval, no KVM — fastest feedback
    ├─► STAGE 3: devshells [parallel]   devShell dry-run matrix
    ├─► STAGE 4: security  [parallel]   SOPS integrity audit
    │
    └─► STAGE 5: vm-tests  [after nmt]  QEMU tests (KVM required), parallel sub-matrix by plane
            ├── smoke        (test_)
            ├── nixos        (nixos_)
            ├── home-lib     (home_ + lib_)
            └── integration  (integration_)

STAGE 6: summary           [always]     aggregate the stage statuses
```

### Plane → CI Job Mapping

| Plane       | CI Job                   | Prefix             | KVM   | Depends on |
| ----------- | ------------------------ | ------------------ | ----- | ---------- |
| Smoke       | `vm-tests (smoke)`       | `test_`            | ✓     | nmt-plane  |
| NixOS       | `vm-tests (nixos)`       | `nixos_`           | ✓     | nmt-plane  |
| HM + Lib    | `vm-tests (home-lib)`    | `home_` `lib_`     | ✓     | nmt-plane  |
| Integration | `vm-tests (integration)` | `integration_`     | ✓     | nmt-plane  |
| **nmt**     | **`nmt-plane`**          | `nmt_`             | **✗** | lint       |

### Dynamic Discovery (no manual list maintenance)

CI uses `nix eval --apply` to filter checks by prefix — **new tests are discovered by CI automatically**:

```bash
# nmt plane discovery example
nix eval ".#checks.x86_64-linux" \
  --apply 'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json
```

### Local Quick Pre-flight (Before Pushing)

```bash
# 1. the nmt plane (<30s, no QEMU)
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" --no-link

# 2. statix lint
nix run nixpkgs#statix -- check .

# 3. structural verification (no builds)
nix eval .#nixosConfigurations --apply builtins.attrNames --json
nix eval .#homeConfigurations  --apply builtins.attrNames --json
nix eval .#checks.x86_64-linux --apply builtins.attrNames --json
```

### Test Counts (2026-10-10, machine-enforced: `tests/docs-ssot.nix` — T8.1; local quick reference: `scripts/sh/test-count.sh`)

| Plane       | Count  | KVM   | Notes                                                                    |
| ----------- | ------ | ----- | ------------------------------------------------------------------------ |
| Smoke       | 1      | ✓     |                                                                           |
| NixOS       | 30     | ✓     | base(11=6+i18n_source+samesource+wsl+portal+sound_gate)+drive(3)+sec(4)+db(4)+hardware(2)+log(1)+security(2)+export(1)+monitor(1)+impermanence(1, T5.14: three independent nixosSystem evaluations pinning the rollback recipe / unit ordering / device gate / neededForBoot / bind mounts / laziness law) |
| HM          | 42     | ✓     | base(3)+i18n_source(1)+editor(1)+sys/base(13+3 source)+shell(2+1 source)+sys(3)+sec(1)+srv(2)+dev(11)+export(1) |
| Lib         | 13     | ✓     | enum + fn + schema + caps (the T4.0 capability-table contract) + validate (the T4.1 Result railway) + targets (the T19.1 source-of-truth census) + deploy (the T21.1 deployment-plane census) + overlays (the T24.2 overlay locality census) + version (the T25.2 nix-types version contract — rev answers where, version answers what; a bump is a deliberate two-file decision) + orc (the T28 orc wallust copy-emitter consumption contract — all seven stations under contract, first run caught the swaync empty activation) + orc-guard (the T30 include-intent guard consumption contract — the third-generation tool-library loop closed out: T28 catches the defect → T29 feeds the guard back upstream 05c658f → this round consumes it back) + pdshell (the T31 loader consumption contract — the four-library family closed out: census/face/combinFrom/lifecycle/NamedFile, five groups, double red on mutation) + roles (the R4 three-layer-chain contract — Law E registry↔directory zero drift both ways + Law F role key whitelist + migration equivalence locks + the P1.5 console bias fix + why provenance) |
| Integration | 1      | ✓     |                                                                           |
| **nmt**     | **16** | **✗** | exp/sys/base(11)+shell(2)+app/editor(1)+srv(2); T27.2 +1: ripgrep — the consumption-grade regression proof of the fork `--` guard (leading-dash needle) |
| **Total**   | **103** |       | VM 86 + nmt 16 (plus 6 repository hygiene checks: pre-commit-check + docs-ssot-check + testscript-syntax-check + module-reachability-check + platform-grammar-check + cache-ssot-check) → 109 checks (cache-ssot +1 gate: cache-ssot-check — the fleet cache-identity drift gate (identity (name/URL/public key) is declared single-source in lib/shared/lang/const.nix (shared.const.cache.fleet) and distributed per-face by capability: platform/nixos/.../nix.nix + platform/darwin/.../nix + home/core/base/nix.nix (round 30: the standalone user plane, gated on caps.system-nix) consume it by value and cannot drift; faces that cannot evaluate hold pinned literal mirrors — CI workflows, cachix.just (YAML/shell cannot import nix), cache.md prose; flake.nix's nixConfig was removed in round 27 — zero cache identity at the entry layer (the real consumption faces have closed, evaluable faces no longer hold literals, and nixConfig trust semantics are a liability for consumers); the gate pins flake.nix's silence as an assertion (the identifier/URL/public-key triple ban — any nixConfig regression goes red); after a rename or key change, a literal that does not follow makes this gate red); T46 +1 gate: platform-grammar-check — the platform directory grammar shape gate (a pure readDir tree walk: the platform/ top level allows only tag directories; under <tag>/ only the reserved system/ + home/ subdomains (at least one of them); every domain must carry a default.nix regex gate; domain-level payload allows only module directories — a bare .nix file = the v3 arch walking-corpse class, a gate-less directory = invisible to every gate; run #369's 82 v3 corpses were all of this defect class, caught by the reachability gate's graph walk, while the shape gate rejects them outright at the address-space layer; no exemption ledger — grammar evolution lands in the same commit as the gate); T41 +1 gate: module-reachability-check — the module-tree reachability gate (every default.nix directory under home/ + platform/ must be reachable from a flake evaluation face: 9 graph roots (3 system + 5 home dual-gate + the devShells domain root) + static/dynamic dual-form edge extraction + comment stripping + the self-healing dual tripwire of the exemption ledger; the first scan caught exp/sys/re dangling — the same class as round 19's srv/cache, a category-level cure for dead code invisible to 14 gates; mutation replay: removing the ./cache wiring makes the gate go red; the round-26 extension (run 38632140441 class): the gate-less-directory reference invariant — import-form static references pointing at directories that exist in the audited tree but carry no default.nix gate (v3 top-level gate residue masked by the corpses' presence, left dangling after the sweep — the class), the discriminant law precise in both directions (trailing slash = dynamic-routing prefix, skipped; out-of-tree target = data binding, skipped); a full-source scan of 420 files, zero violations on the fixed tree); T32 +1 gate: testscript-syntax-check — the python syntax gate over every post-composition testScript (the eval layer calls the module directly to fetch the true text, the build layer compile()s it)+ the lib_shared_orc testScript fix (multi-line contractHeld spliced into a single-line `#` comment — the root cause of the CI lib-plane red); T31 +1: lib_shared_pdshell — the pdshell loader consumption contract (the four-library family closed out: nix-types 97 / nmt 98 / orc 99+100 / pdshell 101); T30 +1: lib_shared_orc_guard — the orc include-intent guard consumption contract (the lock answers WHERE, the test answers WHAT)+ the swaync synthetic entry retired (the swaync-config c8818d9 placeholder adopted — the clean representation); T28 +1: lib_shared_orc — the seven-station wallust copy-emitter consumption contract, first run caught the swaync empty activation (the dead-silent failure mode of a zero-match include); T27.2 predecessor: nmt_home_core_exp_sys_base_ripgrep; T25.2 predecessor: lib_shared_lang_version; T24.2 predecessor: lib_shared_overlays) |
