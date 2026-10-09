# @path: ~/projects/configs/nix-config/tests/nixos/core/srv/monitor-policy.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::nixos::core::srv::monitor-policy
# @source: nixos/core/srv/monitor/{default,healthcheck}.nix
#
# T3.4 acceptance (eval depth, mirrors the i18n-source pattern): the
# REAL monitor modules are imported through a full nixpkgs.lib.nixosSystem
# evaluation — not a mock — for three service-profile shapes. The 60s
# observability contract is asserted structurally:
#
#   1. full-autostart   → prometheus + 5 exporters + loki + grafana
#   2. server-pg-only   → prometheus + [node, postgres] only; loki/grafana off;
#                         healthcheck timer exists for INSTALLED dbs only
#   3. minimal          → monitor plane entirely inert
#
# Plus the layered self-heal contract: probes fire on a 30s cadence
# (OnUnitActiveSec) with 5s accuracy — the 60s window holds with margin.

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # Minimal host-scoped shared the monitor plane consumes (policy only —
  # the monitor modules are pure consumers of the strategy payload).
  mkMockShared =
    profile:
    let
      realEnum = import ../../../../lib/shared/shared/enum.nix { inherit inputs; };
      instance = realEnum.service-profile.${profile};
    in
    {
      services = instance.value; # monitor + db + virt trees ride the payload
      service-profile = instance;
      hostName = "monitor-test";
    };

  # Full NixOS evaluation of the REAL monitor modules under one profile.
  # The module is imported as a PATH so the module system injects its
  # own pkgs/lib/config — the same call shape the production tree uses.
  # nixosSystem comes from the LOCKED flake input (not the test runner's
  # per-plane pkgs) to stay inside the pinned nixpkgs.
  monitorConfig =
    profile:
    (inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inputs = { };
        shared = mkMockShared profile;
      };
      modules = [
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          # The real module (imports healthcheck.nix internally).
          imports = [ ../../../../nixos/core/srv/monitor/default.nix ];
        }
      ];
    }).config;

  full = monitorConfig "full-autostart";
  server = monitorConfig "server-pg-only";
  minimal = monitorConfig "minimal";

  # ── Eval-time assertions (T3.4 acceptance, structural) ────────────
  evalAssertions =
    # 1. full-autostart: the observability kitchen sink
    assert full.services.prometheus.enable == true;
    assert full.services.loki.enable == true;
    assert full.services.grafana.enable == true;
    assert full.services.prometheus.exporters.node.enable == true;
    assert full.services.prometheus.exporters.postgres.enable == true;
    assert full.services.prometheus.exporters.redis.enable == true;
    assert full.services.prometheus.exporters.mysqld.enable == true;
    assert full.services.prometheus.exporters.mongodb.enable == true;
    # 2. server-pg-only: exactly the services this profile runs
    assert server.services.prometheus.enable == true;
    assert server.services.prometheus.exporters.node.enable == true;
    assert server.services.prometheus.exporters.postgres.enable == true;
    assert server.services.prometheus.exporters.mysqld.enable == false;
    assert server.services.loki.enable == false;
    assert server.services.grafana.enable == false;
    # 3. minimal: the whole plane is inert
    assert minimal.services.prometheus.enable == false;
    assert minimal.services.loki.enable == false;
    assert minimal.services.grafana.enable == false;
    # 4. liveness timers: 30s cadence on INSTALLED dbs only
    assert full.systemd.timers."db-healthcheck-postgresql".timerConfig.OnUnitActiveSec == "30s";
    assert full.systemd.timers."db-healthcheck-mysql".timerConfig.OnUnitActiveSec == "30s";
    assert server.systemd.timers."db-healthcheck-postgresql".timerConfig.OnUnitActiveSec == "30s";
    assert !builtins.hasAttr "db-healthcheck-mysql" server.systemd.timers;
    # 5. self-heal layer present on installed dbs (probe service exists)
    assert full.systemd.services."db-healthcheck-redis" ? script;
    # 6. 60s window margin: probe interval + accuracy inside the budget
    assert full.systemd.timers."db-healthcheck-redis".timerConfig.AccuracySec == "5s";
    "eval-assertions-passed";
in
{
  name = "nixos_core_srv_monitor_policy";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 60;
  };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("monitor-policy: three profiles evaluated against the REAL modules"):
        # ${evalAssertions} — rendering this line means the T3.4 matrix
        # (exporters/loki/grafana/30s timers, per-profile) holds.
        machine.succeed("true")
  '';
}
