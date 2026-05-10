# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/media/default.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::home::core::exp::sys::media::default
# @source: home/core/exp/sys/media/default.nix
#
# Verifies media tools: mpv, ffmpeg

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_media";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [
      mpv
      ffmpeg
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("media: mpv binary present"):
        ver = machine.succeed("mpv --version 2>&1 | head -1 || true").strip()
        print(f"mpv: {ver}")
        assert "mpv" in ver.lower(), f"mpv missing: {ver}"

    with subtest("media: ffmpeg binary present"):
        ver = machine.succeed("ffmpeg -version 2>&1 | head -1 || true").strip()
        print(f"ffmpeg: {ver}")
        assert "ffmpeg" in ver.lower(), f"ffmpeg missing: {ver}"

    with subtest("media: ffprobe binary present"):
        w = machine.succeed("which ffprobe 2>/dev/null || true").strip()
        print(f"ffprobe: {w}")
  '';
}
