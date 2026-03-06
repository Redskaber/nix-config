# @path: ~/projects/configs/nix-config/shared.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: self::shared
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - user informations configuration


{ shared, ... }:
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


}


