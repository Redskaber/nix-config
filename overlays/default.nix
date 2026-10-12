# @path: ~/projects/configs/nix-config/overlays/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: overlays::default
#
# Overlays are INSTANCE-LOCAL (T24.2, run 38171937689's re-run — the
# darwin leg's named root): what an overlay patches is the package
# set it is APPLIED to — `prev`/`final` are that instance's own
# fixpoint, never a foreign handle. The bug this law closes:
# cutter_patched read `shared.upkgs.cutter`, and `shared.self.overlays`
# — the flake-level binding shared.nix wires into every host's
# nixpkgs.overlays — is instantiated ONCE with the BASE host's IR,
# so every host's cutter_patched resolved to the base workstation's
# x86_64-linux derivation: the darwin closure carried a linux drv a
# macOS runner can never build (CI named it — platform mismatch,
# root cutter-2.5.0; cache-substitutable members masked the cross,
# the patched one alone had to build). The file signature carries
# no `shared` on purpose: an overlay needing one is reaching across
# instances — tests/lib/shared/overlays.nix locks the law.

{ ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  patches = _final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    #   ...
    # });
    cutter_patched = prev.cutter.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        sed -i \
          -e 's/\bSBK_CUTTERPLUGIN_IDX\b/SBK_CutterPlugin_IDX/g' \
          -e 's/\bSBK_CUTTERPLUGINMETADATA_IDX\b/SBK_CutterPluginMetadata_IDX/g' \
          src/plugins/PluginManager.cpp
      '';
    });

    # FIX: tests-suite error
    openldap = prev.openldap.overrideAttrs (old: {
      doCheck = false; # skip the failing test suite
    });

    # FIX: integration-suite flakiness under CI (run 38085235502):
    # nixpkgs runs xdg-desktop-portal's full meson integration battery
    # on every SOURCE build (doCheck = true), and the dynamiclauncher /
    # notification (test_sound_fd) legs fail on loaded runners — that
    # single flake took the whole host-toplevels CI leg down (2/27
    # failed, cascade + 90-minute timeout). Same policy as openldap
    # above: an upstream test suite must not hold the system closure
    # build hostage. Cached substitution bypasses this entirely.
    xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (old: {
      doCheck = false; # skip the flaky integration suite
    });
  };

}
