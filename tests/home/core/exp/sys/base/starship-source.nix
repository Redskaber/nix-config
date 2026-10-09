# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/starship-source.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::home::core::exp::sys::base::starship-source
# @source: home/core/exp/sys/base/starship.nix
#
# T1.2 (production-tree import): asserts the REAL starship module. The
# interesting contract is the config-file handoff: the prompt itself is
# maintained in the starship-config flake input and linked verbatim via
# xdg.configFile — a broken input wiring (renamed file, dropped link)
# is invisible to binary-presence checks but fatal here.

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # Minimal shared contract consumed by the production module.
  mockShared = {
    # runtime-computed shellIntegrations contract (zsh user)
    shellIntegrations = {
      enableZshIntegration = true;
      enableFishIntegration = false;
      enableBashIntegration = false;
    };
  };

  # ── REAL production import ────────────────────────────────────────
  production = import ../../../../../../home/core/exp/sys/base/starship.nix {
    inherit inputs lib;
    shared = mockShared;
    config = { };
    pkgs = { }; # module consumes no packages
  };

  starship = production.programs.starship;
  tomlLink = production.xdg.configFile."starship.toml";

  # ── Eval-time assertions ──────────────────────────────────────────
  evalAssertions =
    assert starship.enable == true;
    # shellIntegrations composition (zsh user)
    assert starship.enableZshIntegration == true;
    assert starship.enableFishIntegration == false;
    # config handoff: the REAL flake input path, verbatim
    assert tomlLink.source == "${inputs.starship-config}/starship.toml";
    "eval-assertions-passed";
in
{
  name = "home_core_exp_sys_base_starship_source";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 60;
  };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("starship-source: production module evaluated, config handoff intact"):
        # ${evalAssertions} — renders only if the starship-config input
        # wiring still resolves to starship.toml verbatim.
        machine.succeed("true")
  '';
}
