# @path: ~/projects/configs/nix-config/tests/home/export-modules.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::home::export-modules
# @source: export/home/{fcitx5,shell,waybar,yazi}.nix
#
# T2.1 acceptance (HM side): all four homeModules entries are imported
# THROUGH the flake output (inputs.self.homeModules.*) and evaluated
# with home-manager's own evaluator — the exact path an external flake
# takes. waybar's configDir is wired to the real waybar-config input,
# mirroring how the production module consumes it.

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  hmLib = inputs.home-manager.lib;

  minimal = {
    home.username = "tester";
    home.homeDirectory = "/home/tester";
    home.stateVersion = "26.05";
  };

  # ── Enabled: all four modules through the flake output ────────────
  enabled =
    (hmLib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        minimal
        inputs.self.homeModules.fcitx5
        inputs.self.homeModules.shell
        inputs.self.homeModules.waybar
        inputs.self.homeModules.yazi
        {
          redskaber.fcitx5.enable = true;
          redskaber.shell.enable = true;
          redskaber.waybar = {
            enable = true;
            configDir = inputs.waybar-config;
          };
          redskaber.yazi.enable = true;
        }
      ];
    }).config;

  # ── Disabled: defaults must leave the home untouched ─────────────
  disabled =
    (hmLib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        minimal
        inputs.self.homeModules.fcitx5
        inputs.self.homeModules.shell
        inputs.self.homeModules.waybar
        inputs.self.homeModules.yazi
        { }
      ];
    }).config;

  pkgNames = map lib.getName enabled.home.packages;

  # ── Eval-time assertions ──────────────────────────────────────────
  evalAssertions =
    # shell: preset contract
    assert enabled.programs.zsh.enable == true;
    assert enabled.programs.zsh.history.size == 50000;
    assert enabled.programs.zsh.sessionVariables.EDITOR == "nvim";
    assert enabled.programs.zsh.shellAliases.ls == "eza --icons=always";
    assert enabled.programs.zsh.autosuggestion.enable == true;
    # waybar: package from the module scope + config stack handoff
    assert builtins.elem "waybar" pkgNames;
    assert enabled.xdg.configFile."waybar".source == inputs.waybar-config;
    # yazi: plugin preset + wrapper
    assert enabled.programs.yazi.enable == true;
    assert enabled.programs.yazi.shellWrapperName == "yy";
    assert enabled.programs.yazi.plugins ? lazygit;
    assert enabled.programs.yazi.plugins ? smart-enter;
    assert lib.isString enabled.programs.yazi.initLua;
    assert lib.hasInfix "smart-enter" enabled.programs.yazi.initLua;
    # fcitx5: zh-CN preset, single-sourced from HM's own pkgs
    assert enabled.i18n.inputMethod.enable == true;
    assert enabled.i18n.inputMethod.type == "fcitx5";
    assert builtins.length enabled.i18n.inputMethod.fcitx5.addons == 6;
    # incremental-mode promise: disabled modules are inert
    assert disabled.programs.zsh.enable == false;
    assert disabled.programs.yazi.enable == false;
    assert disabled.i18n.inputMethod.enable == false;
    assert !builtins.elem "waybar" (map lib.getName disabled.home.packages);
    "eval-assertions-passed";
in
{
  name = "home_export_modules";
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

    with subtest("export-modules(HM): flake-output imports evaluate, options drive config"):
        # ${evalAssertions} — renders only if all four exported modules
        # behave as their options declare (and stay inert when disabled).
        machine.succeed("true")
  '';
}
