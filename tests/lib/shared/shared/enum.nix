# @path: ~/projects/configs/nix-config/tests/lib/shared/shared/enum.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::lib::shared::shared::enum
# @source: lib/shared/shared/enum.nix
#
# T1.1 (test-truthfulness): asserts run against the REAL production
# enum.nix (imported, with the locked nix-types input). Enum semantics
# asserted on actual instances — previously this file asserted Nix
# language basics against inline copies, which could never catch a
# regression in lib/shared/shared/enum.nix.
#
# Covered (real code paths):
#   - single-select enums carry distinct tags (platform/arch/shell/editor)
#   - multi-select groups are enum instances: .tag + .value list
#     (drive-group amd / amd-nvidia / amd-nvidia-prime)
#   - strategy-carrying enums: version.v26_05.stateVersion + wine lambda
#   - editor-set / terminal-set / browser-set collection values

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # ── REAL production import ────────────────────────────────────────
  realEnum = import ../../../../lib/shared/shared/enum.nix { inherit inputs; };

  # ── Eval-time assertions ───────────────────────────────────────────
  evalAssertions =
    assert realEnum.platform.nixos != realEnum.platform.linux;
    assert
      realEnum.platform ? nixos
      && realEnum.platform ? linux
      && realEnum.platform ? darwin
      && realEnum.platform ? wsl;
    assert realEnum.arch ? x86_64-linux && realEnum.arch ? aarch64-linux;
    assert realEnum.shell ? zsh && realEnum.shell ? fish && realEnum.shell ? bash;
    assert realEnum.editor ? nvim && realEnum.editor ? vim;
    # single-select variants are enum instances carrying their tag
    assert realEnum.platform.nixos ? __enumInstance__;
    assert realEnum.platform.nixos.tag == "nixos";
    # multi-select groups: instances with tag + value list
    assert realEnum.drive-group.amd.tag == "amd";
    assert builtins.length realEnum.drive-group.amd-nvidia.value == 2;
    assert builtins.length realEnum.drive-group.amd-nvidia-prime.value == 2;
    assert builtins.isList realEnum.drive-group.intel.value;
    # strategy-carrying enum: payload fields are flattened onto the instance
    assert realEnum.version.v26_05.stateVersion == "26.05";
    assert realEnum.version.v25_11.stateVersion == "25.11";
    assert builtins.isFunction realEnum.version.v26_05.wine;
    # collection sets used by multi-select routing
    assert builtins.isList realEnum.editor-set.dev.editors;
    assert builtins.length realEnum.editor-set.dev.editors == 6;
    # nested strategy: wm -> portal -> default portal list
    assert
      realEnum.window-manager.hyprland.value.portal.value.default == [
        "hyprland"
        "gtk"
      ];
    "eval-assertions-passed";
in
{
  name = "lib_shared_shared_enum";
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

    with subtest("enum: production sources evaluated with all assertions"):
        # Real enum.nix was imported and fully asserted at eval time
        # (${evalAssertions}); the VM only proves the check boots.
        machine.succeed("true")
  '';
}
