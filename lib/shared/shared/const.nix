# @path: ~/projects/configs/nix-config/lib/shared/shared/const.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::shared::const
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
#
# System-wide constants that do not vary per-user or per-machine.
# These are pure values — no pkgs, no inputs, no enum dependency.
#
# Design: importable at schema stage (phase 1) without any external dependency.

{
  # Nix store secrets runtime mount points (sops-nix convention)
  secrets = {
    # Secrets store Base path from project
    chipr         = "secrets/chipr";
    # Secrets available before user creation (neededForUsers = true)
    forUsersPath  = "/run/secrets-for-users";
    # Standard runtime secrets path
    runtimePath   = "/run/secrets";
  };

  # Default file permission modes (octal strings, as used by sops-nix)
  mode = {
    ownerOnly  = "0400";   # r--------  owner read-only
    groupRead  = "0440";   # r--r-----  owner+group read
    ownerWrite = "0600";   # rw-------  owner read-write
  };

  # XDG base directory names (relative, not absolute paths)
  xdg = {
    config = ".config";
    data   = ".local/share";
    state  = ".local/state";
    cache  = ".cache";
  };
}
