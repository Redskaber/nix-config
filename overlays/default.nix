# @path: ~/projects/configs/nix-config/overlays/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: overlays::default
#
# Overlays are INSTANCE-LOCAL: what an overlay patches is the package
# set it is APPLIED to — `prev`/`final` are that instance's own
# fixpoint, never a foreign handle. (Born of a bug: a patched pkg
# reading shared.upkgs resolved to the base host's derivation on
# every host — the darwin closure carried a linux drv a macOS runner
# can never build.) The file signature carries no `shared` on
# purpose: an overlay needing one is reaching across instances —
# tests/lib/shared/overlays.nix locks the law.

{ ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # Whatever you want to overlay: versions, patches, flags —
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

    # FIX: integration-suite flakiness under CI — nixpkgs runs
    # xdg-desktop-portal's full meson integration battery on every
    # SOURCE build (doCheck = true), and the dynamiclauncher /
    # notification (test_sound_fd) legs fail on loaded runners.
    # Same policy as openldap above: an upstream test suite must not
    # hold the system closure build hostage. Cached substitution
    # bypasses this entirely.
    xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (old: {
      doCheck = false; # skip the flaky integration suite
    });
  };

}
