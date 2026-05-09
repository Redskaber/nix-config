# @path: ~/projects/configs/nix-config/tests/nixos/core/base/sound.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::base::sound
# @source: nixos/core/base/sound.nix
#
# Mirrors production config:
#   services.pulseaudio.enable = false
#   security.rtkit.enable = true
#   services.pipewire.enable = true + alsa + pulse + wireplumber
#   hardware.alsa.enablePersistence = true
#   environment.systemPackages = [pamixer pavucontrol]

{ pkgs, lib, ... }:
{
  name = "nixos_core_base_sound";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    services.pulseaudio.enable = false;
    security.rtkit.enable      = true;
    services.pipewire = {
      enable             = true;
      alsa.enable        = true;
      alsa.support32Bit  = true;
      pulse.enable       = true;
      wireplumber.enable = true;
    };
    hardware.alsa.enablePersistence = true;
    environment.systemPackages = with pkgs; [ pamixer ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("sound: pulseaudio NOT active"):
        rc = machine.execute("systemctl is-active pulseaudio.service")[0]
        assert rc != 0, "pulseaudio should be inactive when pipewire replaces it"

    with subtest("sound: rtkit-daemon active"):
        machine.wait_for_unit("rtkit-daemon.service")
        st = machine.succeed("systemctl is-active rtkit-daemon").strip()
        assert st == "active", f"rtkit-daemon not active: {st}"

    with subtest("sound: pamixer binary present"):
        w = machine.succeed("which pamixer").strip()
        assert "pamixer" in w, f"pamixer not found: {w}"

    with subtest("sound: pipewire unit file listed"):
        rc = machine.execute("systemctl list-unit-files pipewire.service")[0]
        assert rc == 0, "pipewire.service unit not listed"
  '';
}
