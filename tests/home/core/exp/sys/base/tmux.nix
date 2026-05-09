# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/tmux.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::tmux
# @source: home/core/exp/sys/base/tmux.nix
#
# Mirrors production:
#   programs.tmux.enable = true
#   xdg.configFile."tmux".source = inputs.tmux-config

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_tmux";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ tmux ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("tmux: binary present"):
        w = machine.succeed("which tmux").strip()
        assert "tmux" in w, f"tmux not found: {w}"

    with subtest("tmux: version reportable"):
        ver = machine.succeed("tmux -V 2>&1").strip()
        print(f"tmux: {ver}")
        assert "tmux" in ver.lower()

    with subtest("tmux: new-session (detached) lifecycle"):
        machine.succeed("tmux new-session -d -s nixtest 'sleep 5'")
        sessions = machine.succeed("tmux list-sessions 2>&1").strip()
        print(f"sessions: {sessions}")
        assert "nixtest" in sessions, f"Session nixtest not found: {sessions}"
        machine.succeed("tmux kill-session -t nixtest")
        sessions_after = machine.succeed("tmux list-sessions 2>&1 || true").strip()
        assert "nixtest" not in sessions_after, "Session not killed"
  '';
}
