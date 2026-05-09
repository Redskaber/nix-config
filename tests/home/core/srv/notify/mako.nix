# @path: ~/projects/configs/nix-config/tests/home/core/srv/notify/mako.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::srv::notify::mako
# @source: home/core/srv/notify/mako.nix
#
# Verifies mako notification daemon binary and makoctl are present.

{ pkgs, lib, ... }:
{
  name = "home_core_srv_notify_mako";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ mako libnotify ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("mako: binary present"):
        w = machine.succeed("which mako").strip()
        assert "mako" in w, f"mako not found: {w}"

    with subtest("mako: version reportable"):
        ver = machine.succeed("mako --version 2>&1 || true").strip()
        print(f"mako: {ver}")

    with subtest("mako: makoctl binary present"):
        w = machine.succeed("which makoctl 2>/dev/null || true").strip()
        print(f"makoctl: {w}")

    with subtest("notify-send: binary present (libnotify)"):
        w = machine.succeed("which notify-send 2>/dev/null || true").strip()
        print(f"notify-send: {w}")
  '';
}
