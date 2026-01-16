# @path: ~/projects/configs/nix-config/nixos/core/user.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::user


{ inputs
, config
, lib
, pkgs
, ...
}:
{
  # TODO: Configure your system-wide user settings (groups, etc), add more users as needed.
  users = {
    mutableUsers = false;
    #defaultUserShell = pkgs.zsh;
    users = {
      # FIXME: Replace with your username
      kilig = {
        homeMode = "755";
        isNormalUser = true;
        description = "kilig";
        # TODO: Add your SSH public key(s) here, if you plan on using SSH to connect
        openssh.authorizedKeys.keys = [  ];
        # TODO: Be sure to add any other groups you need
        # (such as networkmanager, audio, docker, etc)
        extraGroups = [
          "wheel"             # Sudo
          "networkmanager"    # Network
          "video"             # GPU (hardware)
          "libvirtd"
          "scanner"           # Scanner
          "lp"                # Printer
          "input"             # Inputer (Gaming Box ...)
          "audio"             # GPU (/dev/dri ...)
        ];
        # shell = pkgs.zsh;
        packages = with pkgs; [  ];
        # TODO: You can set an initial password for your user.
        # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
        # Be sure to change it (using passwd) after rebooting!
        # entry: "nixos-enter --root /mnt -c 'passwd your-username'"
        initialPassword = "1024";
      };
    };
  };

  security.sudo.enable = true;    # wheel
}


