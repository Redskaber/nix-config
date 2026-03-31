# @path: ~/projects/configs/nix-config/nixos/core/base/user.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::base::user
# - log: 2026-02-27: sup `sops-nix` used hashedPasswordFile


{ inputs
, shared
, config
, lib
, pkgs
, ...
}:
{
  programs.${shared.user.shell.tag}.enable = true;

  # TODO: Configure your system-wide user settings (groups, etc), add more users as needed.
  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.${shared.user.shell.tag};
    users = {
      ${shared.user.username} = {
        homeMode = "755";
        isNormalUser = true;
        useDefaultShell = true;
        description = shared.user.username;
        # TODO: Add your SSH public key(s) here, if you plan on using SSH to connect
        openssh.authorizedKeys.keys = shared.user.openssh-authKeys;
        # TODO: Be sure to add any other groups you need
        # (such as networkmanager, audio, docker, etc)
        extraGroups = [
          "wheel"             # Sudo
          "networkmanager"    # Network
          "video"             # GPU (hardware)
          "libvirtd"          # Virtual
          "scanner"           # Scanner
          "lp"                # Printer
          "input"             # Inputer (Gaming Box ...)
          "audio"             # GPU (/dev/dri ...)
        ];
        packages = with pkgs; [  ];
        # TODO: You can set an initial password for your user.
        # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
        # Be sure to change it (using passwd) after rebooting!
        # entry: "nixos-enter --root /mnt -c 'passwd your-username'"
        # initialPassword = "1024";

        # Used Sops-nix manager User pwd
        # WARN: pleace used mkpasswd build sops-base ppassword
        # > echo "password" | mkpasswd -s ...
        #   $y$j9T$WFoiErKnEnMcGq0ruQK4K.$4nJAY3LBeBsZBTYSkdTOejKU6KlDmhnfUV3Ll1K/1b....
        hashedPasswordFile = config.sops.secrets.${shared.secrets.nixos.core.base.user.password}.path;
      };
    };
  };

  security.sudo.enable = true;    # wheel


}


