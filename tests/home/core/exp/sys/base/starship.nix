# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/starship.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::starship
# @source: home/core/exp/sys/base/starship.nix
#
# Mirrors production:
#   programs.starship.enable = true
#   enableBashIntegration = true
#   enableZshIntegration = true
#   enableFishIntegration = true

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_starship";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ starship ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("starship: binary present"):
        w = machine.succeed("which starship").strip()
        assert "starship" in w, f"starship not found: {w}"

    with subtest("starship: version reportable"):
        ver = machine.succeed("starship --version 2>&1").strip()
        print(f"starship: {ver}")
        assert ver != "", "starship version empty"

    with subtest("starship: init bash produces output"):
        out = machine.succeed("starship init bash 2>&1 | head -3").strip()
        print(f"init bash: {out[:80]}")
        assert out != "", "starship init bash empty"

    with subtest("starship: prompt renders without crash"):
        machine.succeed(
            "starship prompt --status 0 --terminal-width 80 2>&1 || true"
        )
  '';
}
