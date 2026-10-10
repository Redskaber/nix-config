# @path: ~/projects/configs/nix-config/lib/shared/lang/schema.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::lang::schema
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - nix core information configuration

let
  user =
    {
      username,
      shell,
      openssh-authKeys,
    }@return_user:
    return_user;

  git =
    {
      defaultBranch,
      name,
      email,
      lazygit,
    }@return_git:
    return_git;

  rbw =
    {
      email,
      lock_timeout,
    }@return_rbw:
    return_rbw;

  time =
    {
      used-ip-timeZone,
      timeZone,
    }@return_time:
    return_time;

  i18n =
    {
      defaultLocale,
      extraLocalSetting,
      extraLocales,
      # T2.6 dual-source governance: which nixpkgs instance assembles
      # the input-method stack ("stable" | "unstable"). Modules fingerprint
      # their daemon scope against this declaration at eval time
      # (fn.sameSource).
      nixpkgs-source ? "stable",
    }@return_i18n:
    # T4.0: materialise the default — `@` captures the CALLER's attrset,
    # which does not contain defaults that were never provided (the
    # binding exists, the value does not). Without splicing it back the
    # validator's declared contract never reaches its result — which is
    # exactly how `nixpkgs-source ? "stable"` stayed dead machinery
    # while every leaf carried its own `or "stable"` fallback.
    # When the caller DID provide the key, the splice is identity.
    return_i18n // { inherit nixpkgs-source; };

  # T4.0: unshadowed alias — schema.shared destructures `i18n` as a
  # required param (its functionArgs contract), which shadows this
  # let binding inside that body.
  applyI18n = i18n;

  secrets =
    {
      sshKeyPaths,
      nixos,
      ...
    }@return_secrets:
    return_secrets;

  nixpkgs_config =
    {
      allowUnfree ? true,
      permittedInsecurePackages ? [ ],
    }@return_nixpkgs_config:
    return_nixpkgs_config;

  nixpkgs =
    {
      overlays ? [ ],
      config ? nixpkgs_config,
    }@return_nixpkgs:
    return_nixpkgs;

  shared =
    {
      arch,
      drive,
      platform,
      window-manager,
      display-manager,
      # T10.1: the local sound server axis (enum sound: pipewire |
      # none) — required like its dm/wm siblings so every policy
      # chain answers it; the base policy declares the workstation
      # default, hosts override wholesale per form.
      sound,
      pointer-cursor,
      version,
      editor,
      devDir,
      hostName,
      user,
      git,
      rbw,
      time,
      i18n,
      secrets,
      nixpkgs,
      ...
    }@return_shared:
    # T4.0: nested composition — the i18n validator's defaults are REAL
    # now: schema.shared applies it, so `nixpkgs-source ? "stable"`
    # actually fires. Previously NOTHING called the nested validator —
    # dead machinery discovered when the wsl closure first forced the
    # key (every leaf carried its own `or "stable"` fallback, so the
    # gap stayed invisible until dispatch converged into one reader).
    # The other nested validators are pass-through declarations (no
    # load-bearing defaults) and stay identity-composed.
    return_shared
    // {
      i18n = applyI18n return_shared.i18n;
    };

in
{
  inherit
    user
    git
    rbw
    time
    i18n
    secrets
    nixpkgs
    shared
    ;
}
