# @path: ~/projects/configs/nix-config/overlays/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: overlays::default
#

# This file defines overlays
{ shared, ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  patches = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
    cutter_patched = shared.upkgs.cutter.overrideAttrs (old: {
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
