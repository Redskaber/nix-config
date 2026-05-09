# @path: ~/projects/configs/nix-config/tests/nixos/core/base/i18n.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::base::i18n
# @source: nixos/core/base/i18n.nix
#
# Mirrors production config:
#   i18n.defaultLocale = "en_US.UTF-8"   (shared.i18n.defaultLocale)
#   extraLocales = ["zh_CN.UTF-8/UTF-8"]  (shared.i18n.extraLocales)
#   time.timeZone = "Asia/Shanghai"       (shared.time.timeZone)

{ pkgs, lib, ... }:
{
  name = "nixos_core_base_i18n";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    i18n = {
      defaultLocale    = "en_US.UTF-8";
      extraLocales     = [ "en_US.UTF-8/UTF-8" "zh_CN.UTF-8/UTF-8" ];
    };

    time.timeZone = "Asia/Shanghai";
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("i18n: LANG=en_US.UTF-8 in /etc/locale.conf"):
        lc = machine.succeed("cat /etc/locale.conf").strip()
        print(f"locale.conf: {lc}")
        assert "LANG=en_US.UTF-8" in lc, f"LANG not set: {lc}"

    with subtest("i18n: zh_CN locale generated"):
        avail = machine.succeed("locale -a 2>/dev/null || true").strip()
        print(f"locales (first 200): {avail[:200]}")
        assert "zh_CN" in avail, f"zh_CN not in locale -a: {avail[:200]}"

    with subtest("i18n: timezone is Asia/Shanghai"):
        tz = machine.succeed(
            "cat /etc/timezone 2>/dev/null"
            " || timedatectl show -p Timezone --value 2>/dev/null"
            " || true"
        ).strip()
        print(f"TZ: {tz}")
        assert "Asia/Shanghai" in tz, f"Unexpected TZ: {tz}"
  '';
}
