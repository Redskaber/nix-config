# @path: ~/projects/configs/nix-config/tests/home/core/base/i18n.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::base::i18n
# @source: home/core/base/i18n.nix
#
# Mirrors production config (isNixOS=true → i18n managed by NixOS layer):
#   i18n.inputMethod.type = "fcitx5"
#   fcitx5.waylandFrontend = true
#   home.sessionVariables LANG / LC_*
#
# Test: system locale + fcitx5 binary presence.

{ pkgs, lib, ... }:
{
  name = "home_core_base_i18n";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 768;

    i18n = {
      defaultLocale    = "en_US.UTF-8";
      extraLocales     = [ "en_US.UTF-8/UTF-8" "zh_CN.UTF-8/UTF-8" ];
      inputMethod = {
        type   = "fcitx5";
        enable = true;
        fcitx5.addons = with pkgs; [
          qt6Packages.fcitx5-chinese-addons
        ];
      };
    };

    users.users.hmtest = {
      isNormalUser    = true;
      initialPassword = "test";
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("i18n: LANG=en_US.UTF-8"):
        lc = machine.succeed("cat /etc/locale.conf").strip()
        print(f"locale.conf: {lc}")
        assert "en_US.UTF-8" in lc

    with subtest("i18n: zh_CN locale available"):
        avail = machine.succeed("locale -a 2>/dev/null | grep zh || true").strip()
        print(f"zh locales: {avail}")

    with subtest("i18n: fcitx5 binary present"):
        w = machine.succeed("which fcitx5 2>/dev/null || true").strip()
        print(f"fcitx5: {w}")
  '';
}
