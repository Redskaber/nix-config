# Module Interface Standards

> Status: **active** — new modules MUST follow this document; existing
> modules convert incrementally ("改造即接线", see the migration policy).
> Introduced by the P2 接口化 phase (T2.1/T2.2) of the optimization plan.

This repository's design principles (README §设计原则) promise *增量模式*
("modules can be enabled/disabled individually") and *依赖倒置*. Until
Phase 2 those promises were structural only: the production tree had zero
`options` — every module self-activated against the global `shared`
policy. This document defines the interface contract that closes that gap.

## 1. Two trees, two contracts

| Tree | Audience | Contract |
| --- | --- | --- |
| `nixos/`, `home/` | this user, this machine | consumes `shared` directly; policy-driven, no `enable` needed |
| `export/` | **any external flake** | standalone, options-first, zero `shared` dependency |

Production modules stay policy-driven (that is their value: one `shared.nix`
drives the whole machine). Export modules are the reusable surface — they
are what an external consumer imports through:

```nix
# some other flake
inputs.nix-config.url = "github:Redskaber/nix-config";
…
modules = [ inputs.nix-config.nixosModules.fcitx5 ];
```

## 2. Export module rules (mandatory)

1. **Options first.** Every effect sits behind an option namespace
   `redskaber.<module>.*`; the module body is `config = lib.mkIf cfg.enable`.
   A module that is imported but not enabled must be **completely inert**
   (this is asserted by `tests/*/export-modules.nix`).
2. **`mkEnableOption` + typed knobs.** Sensible defaults for every knob —
   importing with a bare `enable = true` must produce a working setup.
   No required option without a default, except true inputs (e.g.
   `waybar.configDir`: there is nothing sensible to default to).
3. **Zero `shared`.** No import of the policy layer, no flake inputs.
   Only `{ config, lib, pkgs, ... }`.
4. **Scope-parameterized package strategies.** Package lists are exposed
   as functions of the package set (`preset = scope: with scope; [ … ]`)
   and applied to the module's own `pkgs`. This is the *portal.extraPortals
   pattern* — it makes cross-instance package mixing structurally
   impossible (see §4).
5. **Registry + acceptance.** Adding a module = add the file + one line in
   `export/<side>/default.nix` + an entry in the corresponding
   `tests/*/export-modules.nix` matrix. "External flake can import it" is
   proven by evaluating it through `inputs.self.nixosModules.*` /
   `inputs.self.homeModules.*`, never by importing the file directly in
   a test.

## 3. Production module rules (incremental)

- New production modules that are *candidates for reuse* go to `export/`
  first and get consumed by the production tree, not the other way round.
- Existing production modules convert on touch ("改动即改造"): the next
  time a module is edited for any reason, add the `redskaber.*` options
  surface if the module has reuse value. No big-bang conversion marathons
  (the plan's risk R1).
- Policy-driven gating (`shared.services.db.<x>.install`) stays — but see
  the boundary rules below.

## 4. Boundary rules (learned the hard way)

The second machine (`hosts/vm`, server-pg-only profile) exposed a whole
class of violations the single-host tree could not see:

- **Option-level `mkIf` only.** A leaf-level
  `users.users.mongodb.extraGroups = lib.mkIf cond […]` still registers
  the `mongodb` key inside the `attrsOf` submodule and materialises an
  incomplete user. Gate at the option value level:
  `users.users = lib.mkIf cond { mongodb.… = …; }`.
- **No cross-module forcing.** `config.users.users.<service>.name` inside
  an unrelated module (the secrets layer) force-instantiates that user
  on hosts that never install the service. Reference service users by
  literal name, and gate the referencing definition on the same install
  flag the service module uses.
- **Secrets follow services.** A sops secret for a service exists only on
  hosts where that service is installed (`lib.mkIf shared.services…install`).
  Otherwise non-installing hosts fail toplevel evaluation on missing
  secrets — or worse, ship unread secret files.

## 5. Dual-source governance (T2.6, in progress)

`pkgs` (stable) and `shared.upkgs` (unstable) are two different nixpkgs
instances. Any daemon/addon pair assembled from different instances can
break at runtime with an eval-healthy configuration — the fcitx5 incident
(995d8c9). Rules:

- Where a module assembles a *runtime-tight* package family (daemon +
  plugins with version-constrained metadata), draw every member from the
  same scope, parameterized by that scope (§2.4).
- The policy layer may declare the intended source (`i18n.nixpkgs-source`);
  modules fingerprint their actual scope against it at eval time
  (`shared.fn.sameSource`) — mismatches abort evaluation with the incident
  reference instead of dying at the login screen.

## 6. Host scoping

- `hosts/<host>/shared.nix` (optional) overrides the base policy for that
  host; keys replace wholesale (enum instances are attrsets — a recursive
  merge would corrupt their strategy payloads).
- `hostName` inside the merged policy is force-aligned to the host whose
  directory was loaded: the nixos tree routes hardware via
  `../hosts/${shared.hostName}`.
- Adding a machine = `mkdir hosts/<name>` + `default.nix` (+ optional
  `shared.nix`); the flake enumerates `hosts/` itself.
