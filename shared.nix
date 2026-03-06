# @path: ~/projects/configs/nix-config/shared.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: self::shared
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - user informations configuration


{ shared, inputs, ... }:
{
  arch = shared.arch.x86_64-linux;
  hostName = shared.platform.nixos;
  window-manager = shared.window-manager.hyprland;
  version = shared.version;
  devDir = ./home/core/dev;

  editor = "nvim";
  user = {
    username = "kilig";
    shell = "fish";
    openssh-authKeys = [  ];
  };

  git = {
    defaultBranch = "main";
    name = "redskaber";
    email = "redskaber@foxmail.com";
    lazygit.name = "lg";
  };

  rbw = {
    email = "alexredskaber@gmail.com";
    lock_timeout = 600;
  };

  time = {
    used-ip-timeZone = false;
    timeZone = "Asia/Shanghai";
  };

  # sops age from root-dir/secrets/<dir|file>
  secrets = {
    sshKeyPaths = [ "/home/kilig/.ssh/id_ed25519_github" ];
    user-password = "nixos/users/kilig/password";
    home.core.sys.git.github-token = "home/core/sys/git/git";
    srv.db = {
      mongodb-password    = "nixos/srv/db/mongodb/password";
      mysql-root-password = "nixos/srv/db/mysql/users/root/password";
      mysql-user-password = "nixos/srv/db/mysql/users/kilig/password";
      postgresql-appuser-password = "nixos/srv/db/postgresql/users/redskaber/password";
      redis-redis-server-password = "nixos/srv/db/redis/users/redis-server/password";
    };
  };

  # nixpkgs
  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      permittedInsecurePackages = [
        "python3.12-ecdsa-0.19.1"
      ];
    };
  };

}


