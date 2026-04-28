# @path: ~/projects/configs/nix-config/shared.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: self::shared
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - user information configuration


{ shared, inputs, ... }: shared.schema.shared
{
  arch  = shared.enum.arch.x86_64-linux;
  drive = shared.enum.drive-group.intel;
  platform = shared.enum.platform.nixos;
  window-manager  = shared.enum.window-manager.hyprland;
  display-manager = shared.enum.display-manager.ly;
  version = shared.enum.version.v25_11;
  editor  = shared.enum.editor.nvim;
  devDir  = ./home/core/dev;
  hostName = "nixos";

  user = {
    username = "kilig";
    shell = shared.enum.shell.zsh;
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
  i18n = {
    defaultLocale     = "en_US.UTF-8";
    extraLocalSetting = "zh_CN.UTF-8";
    extraLocales      = [ "zh_CN.UTF-8/UTF-8" ];
  };

  # sops age from root-dir/secrets/<dir|file>
  secrets = {
    sshKeyPaths = [ "/home/kilig/.ssh/id_ed25519_github" ];
    nixos.core.base.user.password = "nixos/core/base/users/kilig/password";
    nixos.core.base.nix.user.nixos-github-git-visited = "nixos/core/base/nix/kilig/nixos-github-git-visited";
    nixos.core.srv.db = {
      mongodb.user.password = "nixos/core/srv/db/mongodb/users/kilig/password";
      mysql.root.password = "nixos/core/srv/db/mysql/users/root/password";
      mysql.user.password = "nixos/core/srv/db/mysql/users/kilig/password";
      postgresql.user.password = "nixos/core/srv/db/postgresql/users/kilig/password";
      redis.user.password = "nixos/core/srv/db/redis/users/redis-kilig/password";
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
      # Unsafe pkgs
      permittedInsecurePackages = [
        "python3.12-ecdsa-0.19.1"  # python-renpy
        # "intel-media-sdk-23.2.2" # obs screen -> vaapi
      ];
    };
  };


}


