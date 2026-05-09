# @path: ~/projects/configs/nix-config/tests/nixos/core/base/nix.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::base::nix
# @source: nixos/core/base/nix.nix
#
# Mirrors production config:
#   nix.settings.experimental-features = ["nix-command" "flakes"]
#   nix.settings.trusted-users = ["root" "@wheel"]
#   nix.settings.auto-optimise-store = true

{ pkgs, lib, ... }:
{
  name = "nixos_core_base_nix";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 768;

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users         = [ "root" "@wheel" ];
      auto-optimise-store   = true;
      warn-dirty            = false;
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("nix-daemon.service")

    with subtest("nix: daemon active"):
        st = machine.succeed("systemctl is-active nix-daemon").strip()
        assert st == "active", f"nix-daemon not active: {st}"

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
