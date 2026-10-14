# @path: ~/projects/configs/nix-config/tests/nixos/core/base/nix.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::base::nix
# @source: platform/nixos/system/core/base/nix.nix
#
# Mirrors production config:
#   nix.settings.experimental-features = ["nix-command" "flakes"]
#   nix.settings.trusted-users = ["root" "@wheel"]
#   nix.settings.auto-optimise-store = true

{ pkgs, lib, ... }:
{
  name = "nixos_core_base_nix";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 180;
  };

  nodes.machine = {
    virtualisation.memorySize = 768;

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      auto-optimise-store = true;
      warn-dirty = false;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("nix: daemon socket active and functional"):
        st = machine.succeed("systemctl is-active nix-daemon.socket").strip()
        assert st == "active", f"nix-daemon.socket not active: {st}"
        # via socket daemon ，feature
        # Socket activation spawns the daemon on FIRST connect — on a
        # loaded CI runner that spawn can outlast a single-shot succeed
        # (same race family as the postgresql ensure phase, run
        # 38085235502 audit): poll instead of firing once.
        machine.wait_until_succeeds("nix store info", timeout=60)

    with subtest("nix: experimental-features contain flakes + nix-command"):
        cfg = machine.succeed("nix show-config | grep experimental-features").strip()
        print(f"features: {cfg}")
        assert "flakes" in cfg,      f"flakes missing: {cfg}"
        assert "nix-command" in cfg, f"nix-command missing: {cfg}"

    with subtest("nix: auto-optimise-store = true"):
        cfg = machine.succeed("nix show-config | grep auto-optimise-store").strip()
        print(f"auto-opt: {cfg}")
        assert "true" in cfg, f"auto-optimise-store not true: {cfg}"

    with subtest("nix: nix-instantiate present"):
        w = machine.succeed("which nix-instantiate").strip()
        assert "nix-instantiate" in w, f"nix-instantiate not found: {w}"

    with subtest("nix: eval 1+1 = 2"):
        out = machine.succeed("nix-instantiate --eval -E '1 + 1'").strip()
        assert out == "2", f"Expected 2, got: {out}"
  '';
}
