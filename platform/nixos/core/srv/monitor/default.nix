# @path: ~/projects/configs/nix-config/platform/nixos/core/srv/monitor/default.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: platform::nixos::core::srv::monitor — observability plane (T3.4)
# @directory: https://search.nixos.org/options?channel=unstable&query=prometheus
#
# Metrics pipeline, strategy-driven like everything else in this tree:
# the service-profile enum carries a `monitor` subtree (enable /
# exporters / loki / grafana) which flattens into
# shared.services.monitor — this module is a pure consumer of that
# policy (pipeline view: enum = IR pass, this file = codegen for the
# systemd/prometheus targets).
#
#   ┌─ exporters (per-service collectors, port-per-service) ─┐
#   │  node / postgres / redis / mysqld / mongodb             │
#   └──────────────┬──────────────────────────────────────────┘
#                  ▼
#         prometheus (scrape + TSDB)
#                  ▼
#     loki (logs) ─┬─ grafana (dashboards)  [full-autostart profile]
#
# Acceptance (T3.4): a broken service is observable within 60s —
# the healthcheck timers in healthcheck.nix run on a 30s cadence
# (30s interval + probe runtime < 60s worst case), and exporters
# surface resource-level signals on the same window.

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

  exporterCfg = {
    node = {
      port = 9002;
    };
    postgres = {
      port = 9187;
    };
    redis = {
      port = 9121;
    };
    mysqld = {
      port = 9104;
    };
    mongodb = {
      port = 9216;
    };
  };

  # db exporters need their backing service: an exporter scraping a db
  # the service-profile never installed is a unit that crashes on boot
  # (monitor plane may not resurrect a service the policy turned off).
  dbBackedExporter = {
    postgres = "postgresql";
    mysqld = "mysql";
    redis = "redis";
    mongodb = "mongodb";
  };

  exporterEnabled =
    name:
    builtins.elem name mon.exporters
    && (!dbBackedExporter ? ${name} || shared.services.db.${dbBackedExporter.${name}}.install);

in
{
  imports = [
    ./healthcheck.nix
  ];

  config = lib.mkIf mon.enable {
    # ── Prometheus exporters (metrics sources) ──────────────────────
    services.prometheus.exporters = builtins.mapAttrs (
      name: cfg: (cfg // { enable = exporterEnabled name; })
    ) exporterCfg;

    # ── Prometheus scrape config: the exporters we enable ────────────
    services.prometheus = {
      enable = true;
      port = 9001;
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "localhost:${toString exporterCfg.node.port}" ];
              labels = {
                host = shared.hostName;
                profile = shared.service-profile.tag;
              };
            }
          ];
        }
      ];
    };

    # ── Loki (log aggregation) + Grafana (dashboards) ────────────────
    # Full-observability pair — only the full-autostart profile asks
    # for these (a dev box does not need to BE its own Grafana server).
    services.loki = lib.mkIf mon.loki {
      enable = true;
      # Single-node defaults; configuration data-driven where it matters.
      configuration = {
        server.http_listen_port = 3100;
        auth_enabled = false;

        ingester = {
          lifecycler = {
            address = "127.0.0.1:3100";
            ring.kvstore.store = "inmemory";
            replication_factor = 1;
          };
          chunk_idle_period = "5m";
          chunk_retain_period = "30s";
        };

        schema_config.configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        storage_config = {
          filesystem.directory = "/var/lib/loki/chunks";
          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-index";
            cache_location = "/var/lib/loki/tsdb-cache";
          };
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };
      };
    };

    services.grafana = lib.mkIf mon.grafana {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
        };
        # Provision the local loki+prometheus as datasources on day one.
        "auth.anonymous" = {
          enabled = true;
          org_role = "Viewer";
        };
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:${toString config.services.prometheus.port}";
            isDefault = true;
          }
          {
            name = "Loki";
            type = "loki";
            url = "http://127.0.0.1:3100";
          }
        ];
      };
    };
  };
}
