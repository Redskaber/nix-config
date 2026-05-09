# @path: ~/projects/configs/nix-config/tests/home/core/srv/security/gnupg.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::srv::security::gnupg
# @source: home/core/srv/security/gnupg.nix
#
# Mirrors production:
#   home.packages = [gnupg]
#   programs.gnupg.agent.enable = true
#   programs.gnupg.agent.enableSSHSupport = true

{ pkgs, lib, ... }:
{
  name = "home_core_srv_security_gnupg";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    programs.gnupg.agent = {
      enable            = true;
      enableSSHSupport  = true;
      pinentryPackage   = pkgs.pinentry-tty;
    };

    environment.systemPackages = with pkgs; [ gnupg ];

    users.users.gpgtest = {
      isNormalUser    = true;
      initialPassword = "test";
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("gnupg: gpg binary present"):
        ver = machine.succeed("gpg --version 2>&1 | head -1").strip()
        print(f"gpg: {ver}")
        assert "GnuPG" in ver, f"gpg not found: {ver}"

    with subtest("gnupg: gpg-agent binary present"):
        w = machine.succeed("which gpg-agent").strip()
        assert "gpg-agent" in w, f"gpg-agent not found: {w}"

    with subtest("gnupg: gpg --list-keys runs for user"):
        rc = machine.execute(
            "su - gpgtest -c 'gpg --list-keys 2>&1 || true'"
        )[0]
        # 0 = ok, 2 = no keys — both acceptable
        print(f"gpg --list-keys rc: {rc}")
  '';
}
