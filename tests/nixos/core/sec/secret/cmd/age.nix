# @path: ~/projects/configs/nix-config/tests/nixos/core/sec/secret/cmd/age.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::sec::secret::cmd::age
# @source: nixos/core/sec/secret/cmd/age.nix
#
# Verifies age encryption tool:
#   - age binary present
#   - age-keygen generates a key file
#   - age encrypt/decrypt round-trip succeeds

{ pkgs, lib, ... }:
{
  name = "nixos_core_sec_secret_cmd_age";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ age ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("age: binary present"):
        ver = machine.succeed("age --version 2>&1").strip()
        print(f"age: {ver}")
        assert ver != "", "age not found"

    with subtest("age: key generation"):
        machine.succeed("age-keygen -o /tmp/age_test.key 2>&1")
        rc = machine.execute("test -f /tmp/age_test.key")[0]
        assert rc == 0, "age key not generated"

    with subtest("age: encrypt/decrypt round-trip"):
        # Extract public key from generated key
        pub = machine.succeed(
            "grep '^# public key:' /tmp/age_test.key | awk '{print $NF}'"
        ).strip()
        print(f"public key: {pub}")
        # Encrypt
        machine.succeed("echo 'secret_data_42' > /tmp/plain.txt")
        machine.succeed(f"age -r '{pub}' -o /tmp/cipher.age /tmp/plain.txt")
        # Decrypt
        out = machine.succeed(
            "age -d -i /tmp/age_test.key /tmp/cipher.age"
        ).strip()
        print(f"decrypted: {out}")
        assert out == "secret_data_42", f"Decrypt mismatch: {out}"
  '';
}
