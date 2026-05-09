# @path: ~/projects/configs/nix-config/tests/home/env/dev/nix/default.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::env::dev::nix::default
# @source: home/env/dev/nix/default.nix
#
# Mirrors production buildInputs:
#   nix, nixfmt-rfc-style, statix, alejandra, deadnix, nil, nvd

{ pkgs, lib, ... }:
{
  name = "home_env_dev_nix_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 768;

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    environment.systemPackages = with pkgs; [
      nixfmt-rfc-style
      statix
      alejandra
      deadnix
      nil
      nvd
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("nix_dev: nixfmt present"):
        w = machine.succeed("which nixfmt 2>/dev/null || which nixfmt-rfc-style 2>/dev/null || true").strip()
        print(f"nixfmt: {w}")
        assert w != "", "nixfmt not found"

    with subtest("nix_dev: statix present"):
        w = machine.succeed("which statix").strip()
        assert "statix" in w, f"statix not found: {w}"

    with subtest("nix_dev: alejandra present"):
        w = machine.succeed("which alejandra").strip()
        assert "alejandra" in w, f"alejandra not found: {w}"

    with subtest("nix_dev: deadnix present"):
        w = machine.succeed("which deadnix").strip()
        assert "deadnix" in w, f"deadnix not found: {w}"

    with subtest("nix_dev: nil (LSP) present"):
        w = machine.succeed("which nil").strip()
        assert "nil" in w, f"nil not found: {w}"

    with subtest("nix_dev: nvd present"):
        w = machine.succeed("which nvd").strip()
        assert "nvd" in w, f"nvd not found: {w}"

    with subtest("nix_dev: nix-instantiate eval 1+1"):
        out = machine.succeed("nix-instantiate --eval -E '1+1'").strip()
        assert out == "2", f"eval failed: {out}"
  '';
}
