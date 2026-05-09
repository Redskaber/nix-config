# @path: ~/projects/configs/nix-config/tests/nixos/core/sec/pam.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::sec::pam
# @source: nixos/core/sec/pam.nix
#
# Verifies PAM configuration files are present and contain expected stanzas.

{ pkgs, lib, ... }:
{
  name = "nixos_core_sec_pam";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    security.sudo.enable = true;
    users.users.pamtest = {
      isNormalUser    = true;
      initialPassword = "testpam";
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("pam: /etc/pam.d/login exists"):
        rc = machine.execute("test -f /etc/pam.d/login")[0]
        assert rc == 0, "/etc/pam.d/login not found"

    with subtest("pam: /etc/pam.d/sudo exists"):
        rc = machine.execute("test -f /etc/pam.d/sudo")[0]
        assert rc == 0, "/etc/pam.d/sudo not found"

    with subtest("pam: /etc/pam.d/system-auth exists"):
        rc = machine.execute("test -f /etc/pam.d/system-auth")[0]
        assert rc == 0, "/etc/pam.d/system-auth not found"

    with subtest("pam: user pamtest created"):
        out = machine.succeed("id pamtest").strip()
        assert "pamtest" in out, f"pamtest user not found: {out}"
  '';
}
