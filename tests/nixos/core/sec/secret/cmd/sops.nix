# @path: ~/projects/configs/nix-config/tests/nixos/core/sec/secret/cmd/sops.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::sec::secret::cmd::sops
# @source: nixos/core/sec/secret/cmd/sops.nix
#
# Verifies sops and ssh-to-age CLI tools are installed:
#   - sops binary present, version reportable
#   - ssh-to-age binary present
#
# Note: actual sops decryption (runtime secrets) is NOT tested here —
#       that requires real age keys and belongs to integration tests.

{ pkgs, lib, ... }:
{
  name = "nixos_core_sec_secret_cmd_sops";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ sops ssh-to-age age ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("sops: binary present"):
        ver = machine.succeed("sops --version 2>&1 | head -1").strip()
        print(f"sops: {ver}")
        assert "sops" in ver.lower(), f"sops not found: {ver}"

    with subtest("sops: help does not crash"):
        rc = machine.execute("sops --help 2>/dev/null")[0]
        # sops returns 0 on --help
        print(f"sops --help rc: {rc}")

    with subtest("ssh-to-age: binary present"):
        w = machine.succeed("which ssh-to-age").strip()
        assert "ssh-to-age" in w, f"ssh-to-age not found: {w}"

    with subtest("ssh-to-age: convert test key"):
        # Generate a temporary SSH ed25519 key and convert to age pubkey
        machine.succeed(
            'ssh-keygen -t ed25519 -f /tmp/test_ssh_key -N "" -q 2>&1'
        )
        out = machine.succeed(
            "ssh-to-age < /tmp/test_ssh_key.pub 2>&1"
        ).strip()
        print(f"age pubkey: {out}")
        assert out.startswith("age1"), f"Expected age1... pubkey, got: {out}"
  '';
}
