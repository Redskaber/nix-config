# @path: ~/projects/configs/nix-config/lib/shared/lang/schema.nix
# @author: redskaber
# @datetime: 2026-10-28
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
      # Dual-source governance: which nixpkgs instance assembles the
      # input-method stack ("stable" | "unstable"). Modules fingerprint
      # their daemon scope against this declaration at eval time
      # (fn.sameSource).
      nixpkgs-source ? "stable",
    }@return_i18n:
    # Materialise the default — `@` captures the CALLER's attrset, which
    # does not contain defaults that were never provided (the binding
    # exists, the value does not); without splicing it back the
    # validator's declared contract never reaches its result. When the
    # caller DID provide the key, the splice is identity.
    return_i18n // { inherit nixpkgs-source; };

  # Unshadowed alias — schema.shared destructures `i18n` as a required
  # param (its functionArgs contract), which shadows this let binding
  # inside that body.
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
      # The local sound server axis (enum sound: pipewire | none) —
      # required like its dm/wm siblings so every policy chain answers
      # it; the base policy declares the workstation default, hosts
      # override wholesale per form.
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
    # Nested composition — the i18n validator's defaults are REAL:
    # schema.shared applies it, so `nixpkgs-source ? "stable"` actually
    # fires. The other nested validators are pass-through declarations
    # (no load-bearing defaults) and stay identity-composed.
    return_shared
    // {
      i18n = applyI18n return_shared.i18n;
    };

  # The FLEET-layer validator — the three-layer chain (fleet → role
  # → host) split the policy keys across layers, and each layer owns
  # its own contract:
  #
  #   · class keys (platform) belong to the HOST layer;
  #   · form strategies (window-manager / display-manager / the four
  #     set keys / service-profile) belong to the ROLE layer;
  #   · identity, majority defaults and the `roles` registry belong
  #     HERE, to the fleet.
  #
  # The loader (`lib/shared/default.nix`) re-validates the MERGED
  # result through `schema.shared` — the full 18-key contract still
  # holds downstream; this validator is what the fleet file checks
  # ITSELF against (the pre-layering era called `schema.shared` on
  # the base policy directly, which now fails fast by design: the
  # fleet layer is deliberately class-less).
  fleet =
    {
      arch,
      drive,
      sound,
      pointer-cursor,
      version,
      editor,
      devDir,
      hostName,
      # The management plane — one row per host. Law E (the roles
      # test) pins the registry to the hosts/ directory, both
      # directions; a fleet without a registry is a loader throw,
      # this validator makes it a declared requirement too.
      roles,
      user,
      git,
      rbw,
      time,
      i18n,
      secrets,
      nixpkgs,
      ...
    }@return_fleet:
    # Same nested composition as schema.shared — the i18n defaults
    # materialise at the fleet boundary too (the `@` capture alone
    # would not splice them back; see applyI18n above).
    return_fleet
    // {
      i18n = applyI18n return_fleet.i18n;
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
    fleet
    ;
}
