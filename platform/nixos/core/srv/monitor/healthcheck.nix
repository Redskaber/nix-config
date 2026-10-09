# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/monitor/healthcheck.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: platform::nixos::system::core::srv::monitor::healthcheck — 60s observability (T3.4)
# @directory: https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html
#
# Acceptance for T3.4 is "a broken service is observable within 60s".
# Two layers deliver it, both data-driven off the service-profile:
#
#   1. SELF-HEAL (systemd Restart policy, per installed db):
#      Restart=on-failure + RestartSec=5s — a crash loops back up
#      within seconds and the restart count lands in the journal
#      (loki picks it up when the profile enables it).
#
#   2. LIVENESS TIMERS (observer pattern — one timer+probe pair per
#      INSTALLED db, 30s cadence): even a wedged process that keeps
#      its systemd state "active" gets caught by an application-level
#      probe (pg_isready / redis-cli ping / …) within 30s + probe
#      runtime — strictly inside the 60s window. A failing probe
#      drives the timer's service unit into failed state → journal +
#      `systemctl --failed` → observable.
#
# Both layers live in the monitor plane (db modules stay
# business-only — single responsibility). Probes are per-db
# one-liners carried as DATA (probeCommands); adding a db means
# adding a row, not copying a timer block (open/closed at the data
# level).

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
let
  mon = shared.services.monitor;

  # Probe commands per db — one row per service, executed by a oneshot
  # unit every 30s. Non-zero exit drives the unit into failed state
  # (our observable signal).
  probeCommands = {
    postgresql = "${pkgs.postgresql}/bin/pg_isready -h 127.0.0.1 -p 5432";
    mysql = "${pkgs.mariadb}/bin/mysqladmin ping -h 127.0.0.1 --silent";
    redis = "${pkgs.redis}/bin/redis-cli -h 127.0.0.1 ping";
    mongodb = "${pkgs.mongosh}/bin/mongosh --quiet --host 127.0.0.1 --eval 'db.adminCommand({ping:1})'";
  };

  # Which dbs does THIS host actually run (service-profile install flag)?
  installedDbs = lib.filter (
    name: builtins.hasAttr name shared.services.db && shared.services.db.${name}.install
  ) (builtins.attrNames probeCommands);

  # ── Layer 1: restart policy per installed db unit ──────────────────
  # mkDefault: some upstream unit files already carry a restart policy
  # (mysql ships Restart=on-abnormal) — the monitor plane provides a
  # FALLBACK, it does not override deliberate upstream choices.
  selfHealServices = builtins.listToAttrs (
    builtins.map (db: {
      name = db;
      value = {
        serviceConfig = {
          Restart = lib.mkDefault "on-failure";
          RestartSec = lib.mkDefault "5s";
        };
        unitConfig = {
          StartLimitIntervalSec = lib.mkDefault "60s";
          StartLimitBurst = lib.mkDefault 5;
        };
      };
    }) installedDbs
  );

  # ── Layer 2: liveness probe services + timers, one pair per db ──────
  probeUnit = "db-healthcheck-";

  livenessServices = builtins.listToAttrs (
    builtins.map (name: {
      name = probeUnit + name;
      value = {
        description = "Liveness probe: ${name} (T3.4 observability)";
        serviceConfig = {
          Type = "oneshot";
          # Probe output to the journal — that IS the observation.
          StandardOutput = "journal";
        };
        script = ''
          set -eu
          ${probeCommands.${name}}
          echo "probe ok: ${name}"
        '';
      };
    }) installedDbs
  );

  livenessTimers = builtins.listToAttrs (
    builtins.map (name: {
      name = probeUnit + name;
      value = {
        description = "30s liveness cadence for ${name}";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          # First probe ~30s after boot (give services time), then
          # every 30s — the 60s window holds with margin.
          OnBootSec = "30s";
          OnUnitActiveSec = "30s";
          AccuracySec = "5s";
        };
      };
    }) installedDbs
  );
in
{
  config = lib.mkIf mon.enable {
    systemd = {
      # Layer 1: crash → restart within seconds + journal trail.
      services = selfHealServices // livenessServices;
      # Layer 2: wedged-but-active → probe failure within 30s.
      timers = livenessTimers;
    };
  };
}
