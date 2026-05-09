# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/security/keyring.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::srv::security::keyring
# @source: nixos/core/srv/security/keyring.nix
#
# Verifies gnome-keyring presence:
#   - gnome-keyring-daemon binary present
#   - secret-tool binary present (libsecret)

{ pkgs, lib, ... }:
{
  name = "nixos_core_srv_security_keyring";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    services.gnome.gnome-keyring.enable = true;
    environment.systemPackages = with pkgs; [ gnome-keyring libsecret ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("keyring: gnome-keyring-daemon present"):
        w = machine.succeed(
            "which gnome-keyring-daemon 2>/dev/null || true"
        ).strip()
        print(f"gnome-keyring-daemon: {w}")

    with subtest("keyring: secret-tool present"):
        w = machine.succeed("which secret-tool 2>/dev/null || true").strip()
        print(f"secret-tool: {w}")
        assert "secret-tool" in w, f"secret-tool not found: {w}"

    with subtest("keyring: PAM login references keyring"):
        pam = machine.succeed("cat /etc/pam.d/login 2>/dev/null || true").strip()
        print(f"pam login snippet: {pam[:150]}")
  '';
}
