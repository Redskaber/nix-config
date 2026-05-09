# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/atuin.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::atuin
# @source: home/core/exp/sys/base/atuin.nix
#
# Mirrors production:
#   programs.atuin.enable = true
#   enableBashIntegration / enableZshIntegration / enableFishIntegration = true
#   settings.search_mode = "fuzzy"
#   settings.style = "compact"

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_atuin";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ atuin ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("atuin: binary present"):
        w = machine.succeed("which atuin").strip()
        assert "atuin" in w, f"atuin not found: {w}"

    with subtest("atuin: version reportable"):
        ver = machine.succeed("atuin --version 2>&1").strip()
        print(f"atuin: {ver}")
        assert "atuin" in ver.lower(), f"Unexpected output: {ver}"

    with subtest("atuin: init bash produces output"):
        out = machine.succeed("atuin init bash 2>&1 | head -3").strip()
        print(f"init bash: {out}")
        assert out != "", "atuin init bash empty"

    with subtest("atuin: init zsh produces output"):
        out = machine.succeed("atuin init zsh 2>&1 | head -3").strip()
        print(f"init zsh: {out}")
        assert out != "", "atuin init zsh empty"
  '';
}
