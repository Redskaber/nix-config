# @path: ~/projects/configs/nix-config/home/core/base/i18n.nix
# @author: redskaber
# @datetime: 2026-03-07
# @description: home-manager::core::i18n
# @reference: https://nix-community.github.io/home-manager/options.xhtml#i18n.inputMethod

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  # FIXME(fix@2026-10-08): 与 nixos/core/base/i18n.nix 同根因——
  # Home Manager 侧 fcitx5-with-addons 由 HM 的 pkgs (stable) 组装 daemon，
  # addons 若取 shared.upkgs (unstable) 会出现 core/addon 版本依赖不满足，
  # 导致非 NixOS 平台 (standalone HM) 上中文输入法同样 (not available)。
  # FIX: `with shared.upkgs` -> `with pkgs`，与 daemon 同源。
  #
  # T2.6 (双源治理): 与 nixos 侧同构的 eval 期守卫——addon 列表为作用域
  # 参数化策略，作用域经 `shared.fn.sameSource` 与策略声明源
  # (i18n.nixpkgs-source, 默认 stable) 和 daemon 实际作用域 (HM 的 pkgs)
  # 双重指纹校验，混源在求值期即报错（引用 995d8c9）。
  i18n.inputMethod =
    let
      daemonScope = pkgs;
      # T4.0: the declared source scope is resolved ONCE in the runtime
      # layer (shared.i18nScope) — this module keeps only the sameSource
      # fingerprint guard, not a second copy of the selection branch.
      addonScope =
        shared.fn.sameSource "home i18n.inputMethod.fcitx5 (declared: ${shared.i18n.nixpkgs-source})"
          daemonScope
          shared.i18nScope;
      addonSet =
        scope: with scope; [
          fcitx5-rime # Rhyme input engine (CJK support)
          fcitx5-gtk # GTK application support
          qt6Packages.fcitx5-qt # QT application support
          qt6Packages.fcitx5-chinese-addons # Chinese extensions
          qt6Packages.fcitx5-configtool # GUI config tool
          fcitx5-nord # Nord theme
        ];
    in
    {
      # NixOS layer owns the input method there; macOS owns it via the
      # OS input sources (fcitx5 is not a darwin package) — standalone
      # Linux (incl. wsl) is the only family this module serves.
      # T4.0: composed from resolved capability facts (linux-family minus
      # the nixos system layer) — the platform table answers "who owns
      # the input method", not a re-derived predicate chain.
      enable = shared.caps.linux-family && !shared.caps.nixos-system;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true; # Wayland support
        ignoreUserConfig = false;
        addons = addonSet addonScope;
      };
    };

  # Variables
  home.sessionVariables = {
    LANG = shared.i18n.defaultLocale;
    LC_ADDRESS = shared.i18n.extraLocalSetting;
    LC_IDENTIFICATION = shared.i18n.extraLocalSetting;
    LC_MEASUREMENT = shared.i18n.extraLocalSetting;
    LC_MONETARY = shared.i18n.extraLocalSetting;
    LC_NAME = shared.i18n.extraLocalSetting;
    LC_NUMERIC = shared.i18n.extraLocalSetting;
    LC_PAPER = shared.i18n.extraLocalSetting;
    LC_TELEPHONE = shared.i18n.extraLocalSetting;
    LC_TIME = shared.i18n.extraLocalSetting;
  };

  # Used user config:
  xdg.configFile."fcitx5" = {
    source = inputs.fcitx5-config; # abs path
    recursive = true; # rec-link
    force = true;
  };

}
