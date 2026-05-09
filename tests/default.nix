# @path: ~/projects/configs/nix-config/tests/default.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::default — test matrix registry
#
# Test plane taxonomy:
#
#   Plane 0  Smoke        — baseline VM sanity
#   Plane 1  NixOS-Plane  — nixos/* module tests  (QEMU VM, system services)
#   Plane 2  HM-Plane     — home/* module tests   (QEMU VM + home-manager NixOS module)
#   Plane 3  Lib-Plane    — lib/shared pure-nix   (minimal QEMU VM, eval only)
#   Plane 4  Integration  — NixOS + HM joint       (full QEMU VM)
#
# Path convention:
#   Source path:  home/core/exp/sys/shell/zsh.nix
#   Test path:    tests/home/core/exp/sys/shell/zsh.nix
#
# Run all:    nix flake check
# Run one:    nix build .#checks.x86_64-linux.<name> -L

{ inputs
, shared
, ...
}:
let
  pkgs  = shared.pkgs;

  # ── Runners ────────────────────────────────────────────────────
  # pkgs.testers.runNixOSTest: auto-injects name + hostPkgs
  nixosTest = path: pkgs.testers.runNixOSTest {
    _module.args = { inherit inputs shared; }; # extra Args
    imports = [ path ];
  };

  # low-level runner when manual hostPkgs/name needed
  runTest = path: inputs.nixpkgs.lib.nixos.runTest {
    _module.args = { inherit inputs shared; }; # extra Args
    hostPkgs = pkgs;
    imports  = [ path ];
  };

in
# ── Plane 0: Smoke ─────────────────────────────────────────────
{
  test_calc = nixosTest ./test_calc.nix;
}

# ── Plane 1: NixOS-Plane ───────────────────────────────────────
# Path mirrors: nixos/core/<domain>/<file>.nix
//
{
  # nixos/core/base
  nixos_core_base_boot            = nixosTest ./nixos/core/base/boot.nix;
  nixos_core_base_i18n            = nixosTest ./nixos/core/base/i18n.nix;
  nixos_core_base_network         = nixosTest ./nixos/core/base/network.nix;
  nixos_core_base_nix             = nixosTest ./nixos/core/base/nix.nix;
  nixos_core_base_sound           = nixosTest ./nixos/core/base/sound.nix;
  nixos_core_base_user            = nixosTest ./nixos/core/base/user.nix;
 
  # nixos/core/sec
  nixos_core_sec_secret_cmd_age   = nixosTest ./nixos/core/sec/secret/cmd/age.nix;
  nixos_core_sec_secret_cmd_sops  = nixosTest ./nixos/core/sec/secret/cmd/sops.nix;
  nixos_core_sec_pam              = nixosTest ./nixos/core/sec/pam.nix;
  nixos_core_sec_polkit           = nixosTest ./nixos/core/sec/polkit.nix;

  # nixos/core/srv/db
  nixos_core_srv_db_mongodb       = nixosTest ./nixos/core/srv/db/mongodb.nix;
  nixos_core_srv_db_mysql         = nixosTest ./nixos/core/srv/db/mysql.nix;
  nixos_core_srv_db_postgresql    = nixosTest ./nixos/core/srv/db/postgresql.nix;
  nixos_core_srv_db_redis         = nixosTest ./nixos/core/srv/db/redis.nix;

  # nixos/core/srv/desktop
  nixos_core_srv_desktop_flatpak  = nixosTest ./nixos/core/srv/desktop/flatpak.nix;

  # nixos/core/srv/log
  nixos_core_srv_log_logrotate    = nixosTest ./nixos/core/srv/log/logrotate.nix;

  # nixos/core/srv/security
  nixos_core_srv_security_keyring = nixosTest ./nixos/core/srv/security/keyring.nix;
  nixos_core_srv_security_ssh     = nixosTest ./nixos/core/srv/security/ssh.nix;

}

# ── Plane 2: HM-Plane ──────────────────────────────────────────
# Path mirrors: home/core/<domain>/<file>.nix  /  home/env/<domain>/<file>.nix
//
{
  # home/core/base
  home_core_base_fonts            = nixosTest ./home/core/base/fonts.nix;
  home_core_base_i18n             = nixosTest ./home/core/base/i18n.nix;
  home_core_base_portal           = nixosTest ./home/core/base/portal.nix;

  # home/core/exp/app/editor
  home_core_exp_app_editor_nvim   = nixosTest ./home/core/exp/app/editor/nvim.nix;

  # home/core/exp/sys/base
  home_core_exp_sys_base_git      = nixosTest ./home/core/exp/sys/base/git.nix;
  home_core_exp_sys_base_direnv   = nixosTest ./home/core/exp/sys/base/direnv.nix;
  home_core_exp_sys_base_starship = nixosTest ./home/core/exp/sys/base/starship.nix;
  home_core_exp_sys_base_atuin    = nixosTest ./home/core/exp/sys/base/atuin.nix;
  home_core_exp_sys_base_tmux     = nixosTest ./home/core/exp/sys/base/tmux.nix;
  home_core_exp_sys_base_bat      = nixosTest ./home/core/exp/sys/base/bat.nix;
  home_core_exp_sys_base_fzf      = nixosTest ./home/core/exp/sys/base/fzf.nix;
  home_core_exp_sys_base_ripgrep  = nixosTest ./home/core/exp/sys/base/ripgrep.nix;
  home_core_exp_sys_base_zoxide   = nixosTest ./home/core/exp/sys/base/zoxide.nix;
  home_core_exp_sys_base_eza      = nixosTest ./home/core/exp/sys/base/eza.nix;
  home_core_exp_sys_base_fd       = nixosTest ./home/core/exp/sys/base/fd.nix;
  home_core_exp_sys_base_jq       = nixosTest ./home/core/exp/sys/base/jq.nix;

  # home/core/exp/sys/shell
  home_core_exp_sys_shell_zsh     = nixosTest ./home/core/exp/sys/shell/zsh.nix;
  home_core_exp_sys_shell_fish    = nixosTest ./home/core/exp/sys/shell/fish.nix;

  # home/core/sec  (empty module — binary presence only)
  home_core_sec                   = nixosTest ./home/core/sec/default.nix;

  # home/core/srv/notify
  home_core_srv_notify_mako       = nixosTest ./home/core/srv/notify/mako.nix;

  # home/core/srv/security
  home_core_srv_security_gnupg    = nixosTest ./home/core/srv/security/gnupg.nix;

  # home/env/dev
  home_env_dev_go                 = nixosTest ./home/env/dev/go/default.nix;
  home_env_dev_nix                = nixosTest ./home/env/dev/nix/default.nix;
  home_env_dev_python             = nixosTest ./home/env/dev/python/default.nix;
  home_env_dev_rust               = nixosTest ./home/env/dev/rust/default.nix;
  home_env_dev_typescript         = nixosTest ./home/env/dev/typescript/default.nix;

}

# ── Plane 3: Lib-Plane ─────────────────────────────────────────
# Path mirrors: lib/shared/<domain>/<file>.nix
//
{
  lib_shared_shared_enum          = nixosTest ./lib/shared/shared/enum.nix;
  lib_shared_shared_fn            = nixosTest ./lib/shared/shared/fn.nix;
  lib_shared_shared_schema        = nixosTest ./lib/shared/shared/schema.nix;

}

# ── Plane 4: Integration ───────────────────────────────────────
//
{
  integration_hm_activation       = nixosTest ./integration/hm_activation.nix;
}


