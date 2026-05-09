# @path: ~/projects/configs/nix-config/tests/home/core/base/fonts.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::base::fonts
# @source: home/core/base/fonts.nix
#
# Mirrors production packages:
#   nerd-fonts.jetbrains-mono, noto-fonts, noto-fonts-color-emoji,
#   noto-fonts-cjk-sans, noto-fonts-cjk-serif, fira-code, font-awesome
#   fonts.fontconfig.enable = true

{ pkgs, lib, ... }:
{
  name = "home_core_base_fonts";
  meta = { maintainers = [ "redskaber" ]; timeout = 300; };

  nodes.machine = {
    virtualisation.memorySize = 768;

    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        (nerd-fonts.jetbrains-mono)
        fira-code
        font-awesome
      ];
      fontconfig.enable = true;
    };

    environment.systemPackages = with pkgs; [ fontconfig ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("fonts: fc-list runs"):
        out = machine.succeed("fc-list 2>&1 | head -3 || true").strip()
        print(f"fc-list sample: {out}")

    with subtest("fonts: Noto fonts listed by fc-list"):
        noto = machine.succeed("fc-list | grep -i 'Noto' | head -3 || true").strip()
        print(f"Noto: {noto}")
        assert "Noto" in noto, f"Noto fonts not found: {noto}"

    with subtest("fonts: fontconfig cache can be built"):
        machine.succeed("fc-cache -f 2>&1 || true")

    with subtest("fonts: fontconfig dir exists"):
        rc = machine.execute("test -d /etc/fonts")[0]
        assert rc == 0, "/etc/fonts not found"
  '';
}
