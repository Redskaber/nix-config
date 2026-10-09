# @path: ~/projects/configs/nix-config/nixos/core/srv/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::srv::default

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./db
    ./desktop
    ./hardware
    ./log
    # T3.4 observability plane: exporters/prometheus/loki/grafana +
    # two-layer db healthcheck (self-heal + 30s liveness timers),
    # all gated on the service-profile monitor policy.
    ./monitor
    ./security
  ];

}
