# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/jq.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::jq
# @source: home/core/exp/sys/base/jq.nix
#
# Mirrors production:
#   programs.jq.enable = true

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_jq";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ jq ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("jq: binary present"):
        w = machine.succeed("which jq").strip()
        assert "jq" in w, f"jq not found: {w}"

    with subtest("jq: version reportable"):
        ver = machine.succeed("jq --version 2>&1").strip()
        print(f"jq: {ver}")
        assert "jq" in ver.lower()

    with subtest("jq: parse JSON"):
        out = machine.succeed(
            "echo '{\"key\":\"value\"}' | jq -r '.key'"
        ).strip()
        assert out == "value", f"jq parse failed: {out}"

    with subtest("jq: arithmetic"):
        out = machine.succeed("echo '{}' | jq '1 + 1'").strip()
        assert out == "2", f"jq arithmetic failed: {out}"
  '';
}
