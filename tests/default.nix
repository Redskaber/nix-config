# @path: ~/projects/configs/nix-config/tests/default.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: tests::default — test matrix registry (complete)
#
# Test Plane Taxonomy
# ═══════════════════════════════════════════════════════════════════════
#
#   Plane 0  Smoke            — baseline VM sanity
#   Plane 1  NixOS-Plane      — nixos/* module tests   (QEMU VM, system services)
#   Plane 2  HM-Plane         — home/* module tests    (QEMU VM + packages)
#   Plane 3  Lib-Plane        — lib/shared pure-nix    (minimal QEMU VM, eval only)
#   Plane 4  Integration      — NixOS + HM joint       (full QEMU VM)
#   Plane 5  nmt-Plane        — HM module dotfile      (pure Nix eval, zero VM)
#
# Naming convention:
#   nixos_*        → Plane 1  NixOS-Plane
#   home_*         → Plane 2  HM-Plane
#   lib_*          → Plane 3  Lib-Plane
#   integration_*  → Plane 4  Integration-Plane
#   nmt_*          → Plane 5  nmt-Plane (HOME-MANAGER ONLY, no QEMU)
#
# Path convention:
#   Source:  nixos/core/srv/db/postgresql.nix
#   Test:    tests/nixos/core/srv/db/postgresql.nix
#
# Run all:       nix flake check
# Run one:       nix build .#checks.x86_64-linux.<name> -L
# Run nmt only:  see docs/tests/test-matrix.md §5 (nmt fast path)
#
# Design: uses lib.foldl (a: b: a // b) {} [...] for explicit plane composition.
#         If two planes have the same key, the later plane wins (no silent override).

{
  inputs,
  shared,
  ...
}:
let
  pkgs = shared.pkgs;
  lib = pkgs.lib;

  # ── Runner: nixosTest ──────────────────────────────────────────────
  # pkgs.testers.runNixOSTest auto-injects name + hostPkgs.
  # All QEMU-based planes (0–4) use this runner.
  # (deadnix-cleaned: the low-level `runTest` and `nmtTest` helpers had
  # zero call sites — plane 5 wires its own harness via ./nmt.)
  nixosTest =
    path:
    pkgs.testers.runNixOSTest {
      _module.args = { inherit inputs shared; };
      imports = [ path ];
    };

  # ── Plane definitions ─────────────────────────────────────────────
  # Each plane is an attrset of test derivations.
  # Composition via lib.foldl ensures explicit, ordered merging.

  # ══════════════════════════════════════════════════════════════════
  # Plane 0: Smoke — baseline VM sanity
  # ══════════════════════════════════════════════════════════════════
  plane0_smoke = {
    test_calc = nixosTest ./test_calc.nix;
  };

  # ══════════════════════════════════════════════════════════════════
  # Plane 1: NixOS-Plane — nixos/* module tests (QEMU VM)
  # ══════════════════════════════════════════════════════════════════
  plane1_nixos = {
    # ── core/base ─────────────────────────────────────────────────────
    nixos_core_base_boot = nixosTest ./nixos/core/base/boot.nix;
    nixos_core_base_i18n = nixosTest ./nixos/core/base/i18n.nix;
    nixos_core_base_i18n_source = nixosTest ./nixos/core/base/i18n-source.nix;
    nixos_core_base_i18n_samesource = nixosTest ./nixos/core/base/i18n-samesource.nix;
    # T5.14: the ephemeral-root interpreter (eval-guard, two machines).
    nixos_core_base_impermanence = nixosTest ./nixos/core/base/impermanence.nix;
    # T7.1: the NixOS-WSL fifth system form (the customs door + the
    # chrony delta + the inert law).
    nixos_core_base_wsl = nixosTest ./nixos/core/base/wsl.nix;

    # ── export (T2.1: external-flake import acceptance) ────────────
    nixos_export_modules = nixosTest ./nixos/export-modules.nix;
    nixos_core_base_network = nixosTest ./nixos/core/base/network.nix;
    nixos_core_base_nix = nixosTest ./nixos/core/base/nix.nix;
    # T7.2: the portal capability gate (desktop on / console off)
    # + the vm console flip's whole subtraction, on the real machine.
    nixos_core_base_portal = nixosTest ./nixos/core/base/portal.nix;
    nixos_core_base_sound = nixosTest ./nixos/core/base/sound.nix;
    nixos_core_base_user = nixosTest ./nixos/core/base/user.nix;

    # ── core/drive ────────────────────────────────────────────────────
    nixos_core_drive_amd = nixosTest ./nixos/core/drive/amd.nix;
    nixos_core_drive_intel = nixosTest ./nixos/core/drive/intel.nix;
    nixos_core_drive_nvidia = nixosTest ./nixos/core/drive/nvidia.nix;

    # ── core/sec ──────────────────────────────────────────────────────
    nixos_core_sec_pam = nixosTest ./nixos/core/sec/pam.nix;
    nixos_core_sec_polkit = nixosTest ./nixos/core/sec/polkit.nix;
    nixos_core_sec_secret_cmd_age = nixosTest ./nixos/core/sec/secret/cmd/age.nix;
    nixos_core_sec_secret_cmd_sops = nixosTest ./nixos/core/sec/secret/cmd/sops.nix;

    # ── core/srv/db ───────────────────────────────────────────────────
    nixos_core_srv_db_mongodb = nixosTest ./nixos/core/srv/db/mongodb.nix;
    nixos_core_srv_db_mysql = nixosTest ./nixos/core/srv/db/mysql.nix;
    nixos_core_srv_db_postgresql = nixosTest ./nixos/core/srv/db/postgresql.nix;
    nixos_core_srv_db_redis = nixosTest ./nixos/core/srv/db/redis.nix;

    # ── core/srv/hardware ─────────────────────────────────────────────
    nixos_core_srv_hardware_bluetooth = nixosTest ./nixos/core/srv/hardware/bluetooth.nix;
    nixos_core_srv_hardware_printing = nixosTest ./nixos/core/srv/hardware/printing.nix;

    # ── core/srv/log ──────────────────────────────────────────────────
    nixos_core_srv_log_logrotate = nixosTest ./nixos/core/srv/log/logrotate.nix;

    # ── core/srv/monitor (T3.4 observability) ─────────────────────
    nixos_core_srv_monitor_policy = nixosTest ./nixos/core/srv/monitor-policy.nix;

    # ── core/srv/security ─────────────────────────────────────────────
    nixos_core_srv_security_keyring = nixosTest ./nixos/core/srv/security/keyring.nix;
    nixos_core_srv_security_ssh = nixosTest ./nixos/core/srv/security/ssh.nix;
  };

  # ══════════════════════════════════════════════════════════════════
  # Plane 2: HM-Plane — home/* module tests (QEMU VM + packages)
  # ══════════════════════════════════════════════════════════════════
  plane2_home = {
    # ── home/core/base ────────────────────────────────────────────────
    home_core_base_fonts = nixosTest ./home/core/base/fonts.nix;
    home_core_base_i18n = nixosTest ./home/core/base/i18n.nix;
    # T1.2 production-tree imports (real modules, marker package sets):
    home_core_base_i18n_source = nixosTest ./home/core/base/i18n-source.nix;

    # ── home/core/exp/app/editor ──────────────────────────────────────
    home_core_exp_app_editor_nvim = nixosTest ./home/core/exp/app/editor/nvim.nix;

    # ── home/core/exp/sys/base ────────────────────────────────────────
    home_core_exp_sys_base_atuin = nixosTest ./home/core/exp/sys/base/atuin.nix;
    home_core_exp_sys_base_bat = nixosTest ./home/core/exp/sys/base/bat.nix;
    home_core_exp_sys_base_direnv = nixosTest ./home/core/exp/sys/base/direnv.nix;
    home_core_exp_sys_base_eza = nixosTest ./home/core/exp/sys/base/eza.nix;
    home_core_exp_sys_base_fd = nixosTest ./home/core/exp/sys/base/fd.nix;
    home_core_exp_sys_base_fzf = nixosTest ./home/core/exp/sys/base/fzf.nix;
    home_core_exp_sys_base_fzf_source = nixosTest ./home/core/exp/sys/base/fzf-source.nix;
    home_core_exp_sys_base_git = nixosTest ./home/core/exp/sys/base/git.nix;
    home_core_exp_sys_base_git_source = nixosTest ./home/core/exp/sys/base/git-source.nix;
    home_core_exp_sys_base_jq = nixosTest ./home/core/exp/sys/base/jq.nix;
    home_core_exp_sys_base_ripgrep = nixosTest ./home/core/exp/sys/base/ripgrep.nix;
    home_core_exp_sys_base_starship = nixosTest ./home/core/exp/sys/base/starship.nix;
    home_core_exp_sys_base_starship_source = nixosTest ./home/core/exp/sys/base/starship-source.nix;
    home_core_exp_sys_base_yazi = nixosTest ./home/core/exp/sys/base/yazi.nix;
    home_core_exp_sys_base_tmux = nixosTest ./home/core/exp/sys/base/tmux.nix;
    home_core_exp_sys_base_zoxide = nixosTest ./home/core/exp/sys/base/zoxide.nix;

    # ── home/core/exp/sys/shell ───────────────────────────────────────
    home_core_exp_sys_shell_fish = nixosTest ./home/core/exp/sys/shell/fish.nix;
    home_core_exp_sys_shell_zsh = nixosTest ./home/core/exp/sys/shell/zsh.nix;
    home_core_exp_sys_shell_zsh_source = nixosTest ./home/core/exp/sys/shell/zsh-source.nix;

    # ── export (T2.1: external-flake import acceptance) ──────────────
    home_export_modules = nixosTest ./home/export-modules.nix;

    # ── home/core/exp/sys/monitor ─────────────────────────────────────
    home_core_exp_sys_monitor = nixosTest ./home/core/exp/sys/monitor/default.nix;

    # ── home/core/exp/sys/media ───────────────────────────────────────
    home_core_exp_sys_media = nixosTest ./home/core/exp/sys/media/default.nix;

    # ── home/core/exp/sys/fs ──────────────────────────────────────────
    home_core_exp_sys_fs = nixosTest ./home/core/exp/sys/fs/default.nix;

    # ── home/core/sec ─────────────────────────────────────────────────
    home_core_sec = nixosTest ./home/core/sec/default.nix;

    # ── home/core/srv/notify ──────────────────────────────────────────
    home_core_srv_notify_mako = nixosTest ./home/core/srv/notify/mako.nix;

    # ── home/core/srv/security ────────────────────────────────────────
    home_core_srv_security_gnupg = nixosTest ./home/core/srv/security/gnupg.nix;

    # ── home/env/dev ──────────────────────────────────────────────────
    home_env_dev_c = nixosTest ./home/env/dev/c/default.nix;
    home_env_dev_cpp = nixosTest ./home/env/dev/cpp/default.nix;
    home_env_dev_go = nixosTest ./home/env/dev/go/default.nix;
    home_env_dev_java = nixosTest ./home/env/dev/java/default.nix;
    home_env_dev_lua = nixosTest ./home/env/dev/lua/default.nix;
    home_env_dev_nix = nixosTest ./home/env/dev/nix/default.nix;
    home_env_dev_python = nixosTest ./home/env/dev/python/default.nix;
    home_env_dev_re = nixosTest ./home/env/dev/re/default.nix;
    home_env_dev_rust = nixosTest ./home/env/dev/rust/default.nix;
    home_env_dev_typescript = nixosTest ./home/env/dev/typescript/default.nix;
    home_env_dev_zig = nixosTest ./home/env/dev/zig/default.nix;
  };

  # ══════════════════════════════════════════════════════════════════
  # Plane 3: Lib-Plane — lib/shared pure-nix (minimal QEMU VM)
  # ══════════════════════════════════════════════════════════════════
  plane3_lib = {
    # T4.0: the platform dispatch-table contract (caps vectors +
    # strategy lambdas) — the distribution layer has its own test now.
    lib_shared_lang_caps = nixosTest ./lib/shared/lang/caps.nix;
    lib_shared_lang_enum = nixosTest ./lib/shared/lang/enum.nix;
    lib_shared_lang_fn = nixosTest ./lib/shared/lang/fn.nix;
    lib_shared_lang_schema = nixosTest ./lib/shared/lang/schema.nix;
    # T4.1: the Result railway contract (ok/err lanes, front-end
    # precedence, boundary throw) — typed error handling has a test now.
    lib_shared_lang_validate = nixosTest ./lib/shared/lang/validate.nix;
  };

  # ══════════════════════════════════════════════════════════════════
  # Plane 4: Integration-Plane — NixOS + HM joint activation
  # ══════════════════════════════════════════════════════════════════
  plane4_integration = {
    integration_hm_activation = nixosTest ./integration/hm_activation.nix;
  };

  # ══════════════════════════════════════════════════════════════════
  # Plane 5: nmt-Plane — HM dotfile assertions (zero VM, pure eval)
  # ══════════════════════════════════════════════════════════════════
  plane5_nmt = import ./nmt { inherit inputs shared; };

in
# Explicit plane composition via lib.foldl.
# If two planes share a key, the later plane wins (no silent override).
#
# Two faces, one evaluation (T7.3): the flat `checks` attrset is
# what checks.${system} consumes (unchanged shape — one derivation
# per attr, exactly what `nix flake check` expects); the `planes`
# groups expose the SAME derivations under the taxonomy's own
# grouping so CI stages can hand a whole plane to nix-eval-jobs-
# based builders (nix-fast-build -f .#api.checks.planes.nixos)
# instead of discovering members and building them one at a time.
# Members are shared thunks — addressing them twice costs nothing
# (the T5.10 single-instantiation discipline).
{
  checks = lib.foldl (a: b: a // b) { } [
    plane0_smoke
    plane1_nixos
    plane2_home
    plane3_lib
    plane4_integration
    plane5_nmt
  ];

  planes = {
    smoke = plane0_smoke;
    nixos = plane1_nixos;
    home = plane2_home;
    lib = plane3_lib;
    integration = plane4_integration;
    nmt = plane5_nmt;
  };
}
