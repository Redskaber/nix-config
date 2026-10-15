# @path: ~/projects/configs/nix-config/lib/shared/lang/const.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::lang::const
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
#
# System-wide constants that do not vary per-user or per-machine.
# These are pure values — no pkgs, no inputs, no enum dependency.
#
# Design: importable at schema stage (phase 1) without any external dependency.

{
  # The fleet's public binary-cache identity — the SSOT for the pull
  # side. Distribution follows each consumer plane's capability: the
  # nix-evaluating sides consume it BY VALUE (platform/nixos/system/
  # core/base/nix.nix + platform/darwin/system/nix + home/core/base/
  # nix.nix — the standalone user plane — via shared.const,
  # impossible to drift), while the planes that cannot evaluate nix
  # carry pinned LITERAL mirrors: the CI workflows,
  # scripts/just/cachix.just, and the prose in docs/guides/cache.md.
  # The flake's own nixConfig is deliberately absent (round 27) —
  # the entry layer carries no cache identity: every consumer the
  # fleet actually has is covered by the planes above, and a
  # flake-level literal would be the only mirror on a plane that CAN
  # evaluate the const. tests/cache-ssot.nix pins every mirror to
  # these values and pins flake.nix's silence. Query order is
  # priority-driven: the cache advertises priority 41, behind
  # cache.nixos.org's 40, so shared paths stay official and the
  # free tier serves only the Hydra gap.
  cache = {
    fleet = rec {
      name = "redskaber-nix-config";
      url = "https://${name}.cachix.org";
      publicKey = "redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw=";
    };
  };

  # Nix store secrets runtime mount points (sops-nix convention)
  secrets = {
    # Secrets store Base path from project
    chipr = "secrets/chipr";
    # Secrets available before user creation (neededForUsers = true)
    forUsersPath = "/run/secrets-for-users";
    # Standard runtime secrets path
    runtimePath = "/run/secrets";
  };

  # Default file permission modes (octal strings, as used by sops-nix)
  mode = {
    ownerOnly = "0400"; # r--------  owner read-only
    groupRead = "0440"; # r--r-----  owner+group read
    ownerWrite = "0600"; # rw-------  owner read-write
  };

  # XDG base directory names (relative, not absolute paths)
  xdg = {
    config = ".config";
    data = ".local/share";
    state = ".local/state";
    cache = ".cache";
    userDirs = {
      desktop = "Desktop";
      documents = "Documents";
      download = "Downloads";
      music = "Music";
      pictures = "Pictures";
      publicShare = "Public";
      templates = "Templates";
      videos = "Videos";
    };
  };
}
