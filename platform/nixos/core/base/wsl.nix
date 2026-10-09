# @path: ~/projects/configs/nix-config/platform/nixos/core/base/wsl.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: platform::nixos::system::core::base::wsl — NixOS-WSL system declaration (T3.1)
# @directory: https://github.com/nix-community/NixOS-WSL
#
# System-level WSL facts, kept in ONE place with an explicit boundary
# (readme principle: 边界明确). The user-space half of the specialisation
# lives in platform/wsl/home/x86_64-linux.nix so that a WSL host on a
# non-Nix distro (Ubuntu + standalone home-manager) still consumes it;
# this file only participates when the WSL distro itself IS NixOS
# (NixOS-WSL).
#
# Activation gate (T4.0): the capability fact resolved from the
# platform dispatch table (enum.nix caps vector, published as
# shared.caps.wsl) — every regular host evaluates this module to a
# no-op, so the tree stays uniform and the specialisation is opt-in
# through the host policy chain (strategy pattern: the enum carries
# the behaviour selector).

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf shared.caps.wsl {
    # ── wsl.conf: the WSL2 distro manifest ──────────────────────────
    # Mirrors what NixOS-WSL would inject, kept declarative here so the
    # contract is visible and diffable in-repo (not hidden in an image).
    environment.etc."wsl.conf".text = lib.generators.toINI { } {
      boot = {
        # systemd inside WSL2 (systemd interaction contract).
        systemd = true;
      };
      automount = {
        enabled = true;
        # /mnt/c, /mnt/d … with metadata for correct perms on DrvFs.
        options = "metadata,umask=22,fmask=11";
        mountFsTab = false;
      };
      interop = {
        # Run .exe from WSL ($ notepad.exe) and keep them out of PATH
        # pollution when unwanted (binfmt below does the execution).
        enabled = true;
        appendWindowsPath = true;
      };
      network = {
        generateHosts = true;
        generateResolvConf = false;
      };
      user = {
        default = shared.user.username;
      };
    };

    # resolv.conf is managed by WSL's own network stack when
    # generateResolvConf=false — point at the Windows resolver.
    environment.etc."resolv.conf".text = ''
      nameserver 10.255.255.254
    '';

    # ── Windows interop: binfmt registration for PE executables ─────
    # WSL's default binfmt handles .exe when interop.enabled; register
    # the WSL interpreter explicitly so the behaviour survives
    # environment reloads (systemd-binfmt service reads this at boot).
    boot.binfmt.registrations.WSLInterop = lib.mkDefault {
      wrapInterpreterInShell = false;
      interpreter = "/init";
      magicOrExtension = ".exe";
      recognitionType = "extension";
      preserveArgvZero = true;
      matchCredentials = true;
    };

    # ── systemd interaction (headless distro realities) ───────────────
    # No display manager / VT: these units must not gate multi-user.
    systemd.services."serial-getty@tty1".enable = lib.mkDefault false;
    services.xserver.enable = lib.mkDefault false;

    # WSL userland helpers (system side; the user-space half lives in
    # platform/wsl via the in-tree pkgs/wslview shim).
    environment.systemPackages = [ pkgs.wslview ];

    # WSL2 clock skew guard: chrony syncs against the Windows host
    # clock after resume (dual-kernel time drift is a classic WSL issue).
    services.chrony = {
      enable = lib.mkDefault true;
      servers = [
        "time.cloudflare.com"
        "time.aws.com"
      ];
    };
  };
}
