# @path: ~/projects/configs/nix-config/tests/nixos/export-modules.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::nixos::export-modules
# @source: export/nixos/{portal,fcitx5}.nix
#
# T2.1 acceptance: "an external flake can import any exported module."
# Both nixosModules entries are imported THROUGH the flake output
# (inputs.self.nixosModules.*) — exactly the path an external consumer
# takes — and evaluated with nixpkgs.lib.nixosSystem, once enabled and
# once left at defaults (the incremental-mode promise: a disabled module
# must be completely inert).

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  nixosSystem = inputs.nixpkgs.lib.nixosSystem;

  base = [
    { nixpkgs.hostPlatform = "x86_64-linux"; }
  ];

  # ── Enabled: both modules through the flake output ───────────────
  enabled = nixosSystem {
    modules = base ++ [
      inputs.self.nixosModules.fcitx5
      inputs.self.nixosModules.portal
      {
        redskaber.fcitx5.enable = true;
        redskaber.portal = {
          enable = true;
          backend = "niri";
        };
      }
    ];
  };

  # ── Disabled: defaults must leave the system untouched ────────────
  disabled = nixosSystem {
    modules = base ++ [
      inputs.self.nixosModules.fcitx5
      inputs.self.nixosModules.portal
      { }
    ];
  };

  addons = enabled.config.i18n.inputMethod.fcitx5.addons;
  portal = enabled.config.xdg.portal;
  addonNames = map lib.getName addons;
  portalNames = map lib.getName portal.extraPortals;

  # ── Eval-time assertions ──────────────────────────────────────────
  evalAssertions =
    # fcitx5: enabled module assembles the daemon + zh-CN preset
    assert enabled.config.i18n.inputMethod.type == "fcitx5";
    assert enabled.config.i18n.inputMethod.enable == true;
    assert enabled.config.i18n.inputMethod.fcitx5.waylandFrontend == true;
    assert builtins.isList addons && builtins.length addons == 7;
    assert builtins.elem "fcitx5-chinese-addons" addonNames;
    assert builtins.elem "fcitx5-rime" addonNames;
    # portal: niri backend wires wlr + gtk
    assert portal.enable == true;
    assert portal.wlr.enable == true;
    assert portal.xdgOpenUsePortal == true;
    # the portal module normalises interface lists into ';'-joined strings
    assert
      let
        v = portal.config.common.default;
      in
      (lib.isString v && lib.hasInfix "wlr" v && lib.hasInfix "gtk" v)
      ||
        v == [
          "wlr"
          "gtk"
        ];
    assert builtins.elem "xdg-desktop-portal-wlr" portalNames;
    assert builtins.elem "xdg-desktop-portal-gtk" portalNames;
    # incremental-mode promise: disabled modules are inert
    assert disabled.config.i18n.inputMethod.enable == false;
    assert disabled.config.xdg.portal.enable == false;
    "eval-assertions-passed";
in
{
  name = "nixos_export_modules";
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

    with subtest("export-modules(nixos): flake-output imports evaluate, options drive config"):
        # ${evalAssertions} — renders only if both exported modules behave
        # as options declare (and stay inert when disabled).
        machine.succeed("true")
  '';
}
