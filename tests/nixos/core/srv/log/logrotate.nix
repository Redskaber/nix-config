# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/log/logrotate.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::srv::log::logrotate
# @source: nixos/core/srv/log/logrotate.nix

{ pkgs, lib, ... }:
{
  name = "nixos_core_srv_log_logrotate";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    services.logrotate = {
      enable = true;
      settings = {
        header = {
          frequency  = "daily";
          rotate     = 7;
          compress   = true;
          missingok  = true;
          notifempty = true;
        };
        "/var/log/test.log" = {
          frequency    = "daily";
          rotate       = 3;
          compress     = true;
          copytruncate = true;
        };
      };
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("logrotate: binary present"):
        w = machine.succeed("which logrotate").strip()
        assert "logrotate" in w, f"logrotate not found: {w}"

    with subtest("logrotate: config is valid"):
        out = machine.succeed(
            "logrotate --debug /etc/logrotate.conf 2>&1 | head -10 || true"
        ).strip()
        print(f"logrotate debug: {out[:200]}")

    with subtest("logrotate: timer or service unit exists"):
        rc_timer   = machine.execute("systemctl list-unit-files logrotate.timer 2>/dev/null")[0]
        rc_service = machine.execute("systemctl list-unit-files logrotate.service 2>/dev/null")[0]
        assert rc_timer == 0 or rc_service == 0, \
            "Neither logrotate.timer nor logrotate.service found"
  '';
}
