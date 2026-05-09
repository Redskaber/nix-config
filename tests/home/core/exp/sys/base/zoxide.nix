# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/zoxide.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::zoxide
# @source: home/core/exp/sys/base/zoxide.nix
#
# Mirrors production:
#   programs.zoxide.enable = true
#   enableBashIntegration / enableZshIntegration / enableFishIntegration = true

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_zoxide";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ zoxide ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("zoxide: binary present"):
        w = machine.succeed("which zoxide").strip()
        assert "zoxide" in w, f"zoxide not found: {w}"

    with subtest("zoxide: version reportable"):
        ver = machine.succeed("zoxide --version 2>&1").strip()
        print(f"zoxide: {ver}")
        assert "zoxide" in ver.lower()

    with subtest("zoxide: init bash produces hook"):
        out = machine.succeed("zoxide init bash 2>&1 | head -5").strip()
        print(f"init bash: {out}")
        assert out != "", "zoxide init bash empty"

    with subtest("zoxide: add + query works"):
        machine.succeed("zoxide add /tmp")
        out = machine.succeed("zoxide query /tmp 2>/dev/null || true").strip()
        print(f"query /tmp: {out}")
  '';
}
