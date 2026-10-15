# @path: ~/projects/configs/nix-config/tests/home/core/base/nix.nix
# @author: redskaber
# @datetime: 2026-10-16
# @description: tests::home::core::base::nix
# @source: home/core/base/nix.nix
#
# Production-tree import (the i18n-source precedent): the REAL
# home/core/base/nix.nix, mounted through home-manager's NixOS
# module on one VM for BOTH gate states — two users, two capability
# rows, one closure:
#
#   hmwsl   (wsl-class row:     system-nix = false) → renders
#           ~/.config/nix/nix.conf + registry.json through HM's own
#           misc/nix module — the closure BUILD runs the file's
#           checkPhase (`nix config show`), so grammar is asserted
#           at build depth, and the testScript asserts the content:
#           fleet-headed substituters/keys (from the REAL const.nix
#           — identity flows end-to-end), experimental-features,
#           the registry stance.
#   hmnixos (nixos-class row:    system-nix = true)  → the module
#           stays SILENT (the nix.conf priority chain: a user file
#           would shadow the system one per-setting on hosts that
#           HAVE a system plane — the regression this leg pins).
#
# Mutating the production gate (dropping the mkIf, flipping the
# caps cell) turns exactly one leg red — no VM boot required beyond
# the closure build the test already pays for.

{
  inputs,
  pkgs,
  lib,
  shared,
  ...
}:
let
  onUser = "hmwsl";
  offUser = "hmnixos";

  # REAL phase-1 const (pure values, no deps) — the fleet identity
  # the assertions pin is the same one the flake's shared carries.
  const = import ../../../../lib/shared/lang/const.nix;

  # Minimal shared contract consumed by the production module: the
  # resolved caps row (only system-nix matters to this module) plus
  # the real const. The class difference IS the test.
  mockShared =
    systemNix:
    {
      inherit const;
    }
    // {
      caps = {
        linux-family = true;
        nixos-system = false;
        wsl = !systemNix; # wsl-class row for the ON leg, linux-class for OFF
        darwin = false;
        system-nix = systemNix;
      };
    };

  # The REAL production module, carried into the HM submodule eval.
  productionModule = ../../../../home/core/base/nix.nix;

  userModule = user: classShared: {
    _module.args = {
      shared = classShared;
      inherit inputs;
    };
    imports = [ productionModule ];
    home = {
      username = user;
      homeDirectory = "/home/${user}";
      stateVersion = "${shared.version.value.stateVersion}";
    };
  };
in
{
  name = "home_core_base_nix";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 300;
  };

  nodes.machine = {
    virtualisation.memorySize = 768;

    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${onUser} = userModule onUser (mockShared false);
      users.${offUser} = userModule offUser (mockShared true);
    };

    users.users = {
      ${onUser} = {
        isNormalUser = true;
        initialPassword = "test";
      };
      ${offUser} = {
        isNormalUser = true;
        initialPassword = "test";
      };
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-${onUser}.service")
    machine.wait_for_unit("home-manager-${offUser}.service")

    with subtest("nix(HM): user nix.conf rendered on the system-less class"):
        conf = machine.succeed("cat /home/${onUser}/.config/nix/nix.conf")
        print(conf)
        assert "${const.cache.fleet.url}" in conf, "fleet cache url missing"
        assert "${const.cache.fleet.publicKey}" in conf, "fleet public key missing"
        assert "experimental-features" in conf, "experimental-features missing"
        assert "pipe-operators" in conf, "pipe-operators missing"
        assert "flake-registry =" in conf, "flake-registry stance missing"

    with subtest("nix(HM): standalone closure cache set is darwin-composition"):
        assert "nix-community.cachix.org" in conf, "nix-community cache missing"
        assert "cache.nixos.org" in conf, "official cache missing"
        assert "mirrors.tuna.tsinghua.edu.cn" in conf, "CN mirror missing"

    with subtest("nix(HM): user registry pins the flake inputs"):
        reg = machine.succeed("cat /home/${onUser}/.config/nix/registry.json")
        print(reg[:400])
        assert "nixpkgs" in reg, "nixpkgs pin missing from user registry"

    with subtest("nix(HM): module silent on the system-nix class"):
        # The priority chain: a user-level nix.conf would SHADOW the
        # system plane per-setting — silence is the contract there.
        machine.succeed("test ! -e /home/${offUser}/.config/nix/nix.conf")
        machine.succeed("test ! -e /home/${offUser}/.config/nix/registry.json")
  '';
}
