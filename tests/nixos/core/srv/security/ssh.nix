# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/security/ssh.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::srv::security::ssh
# @source: nixos/core/srv/security/ssh.nix
#
# Verifies OpenSSH server hardening:
#   - sshd.service active
#   - listening on port 22
#   - PasswordAuthentication = no
#   - PermitRootLogin = no

{ pkgs, lib, ... }:
{
  name = "nixos_core_srv_security_ssh";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.server = {
    virtualisation.memorySize = 512;

    services.openssh = {
      enable = true;
      ports  = [ 22 ];
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin        = "no";
      };
    };

    users.users.sshtest = {
      isNormalUser    = true;
      initialPassword = "unused";
    };
  };

  testScript = ''
    start_all()
    server.wait_for_unit("sshd.service")

    with subtest("ssh: sshd active"):
        st = server.succeed("systemctl is-active sshd").strip()
        assert st == "active", f"sshd not active: {st}"

    with subtest("ssh: listening on port 22"):
        server.wait_until_succeeds("ss -tlnp | grep ':22'", timeout=30)
        out = server.succeed("ss -tlnp | grep ':22'").strip()
        print(f"port 22: {out}")
        assert ":22" in out

    with subtest("ssh: PasswordAuthentication = no"):
        cfg = server.succeed(
            "sshd -T 2>/dev/null | grep -i passwordauthentication"
        ).strip()
        print(f"PasswordAuthentication: {cfg}")
        assert "no" in cfg.lower(), f"PasswordAuthentication not 'no': {cfg}"

    with subtest("ssh: PermitRootLogin = no"):
        cfg = server.succeed(
            "sshd -T 2>/dev/null | grep -i permitrootlogin"
        ).strip()
        print(f"PermitRootLogin: {cfg}")
        assert "no" in cfg.lower(), f"PermitRootLogin not 'no': {cfg}"
  '';
}
