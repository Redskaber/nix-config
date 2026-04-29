# @path: ~/projects/configs/nix-config/docs/tmpl/shared.nix.tmpl
# @author: redskaber
# @description: self::shared — policy layer template
#
# NOTE: This is a template. Do not import it directly into Nix.
#       Run `just shared-generate <username>` to substitute kilig
#       and overwrite shared.nix. Edit this file, not shared.nix.
#
# Single source of truth:
#   username appears only here; propagated to shared.nix via generation,
#   never via sed in-place patch (mutation breaks declarative invariant).

{ shared, inputs, ... }: shared.schema.shared
{
  arch  = shared.enum.arch.x86_64-linux;
  drive = shared.enum.drive-group.intel;
  platform = shared.enum.platform.nixos;
  window-manager  = shared.enum.window-manager.hyprland;
  display-manager = shared.enum.display-manager.ly;
  version = shared.enum.version.v25_11;
  editor  = shared.enum.editor.nvim;
  devDir  = "${shared.self}/home/core/dev";
  hostName = "nixos";

  user = {
    username = "kilig";
    shell = shared.enum.shell.zsh;
    openssh-authKeys = [ ];
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

  # sops age key paths derived from username (secrets paths follow username)
  secrets = {
    sshKeyPaths = [ "/home/kilig/.ssh/id_ed25519_github" ];
    nixos.core.base.user.password                 = "nixos/core/base/user/kilig/password";
    nixos.core.base.nix.user.github.access-token  = "nixos/core/base/nix/users/kilig/github/access-token";
    nixos.core.srv.db.mongodb.user.password       = "nixos/core/srv/db/mongodb/users/kilig/password";
    nixos.core.srv.db.mysql.root.password         = "nixos/core/srv/db/mysql/users/root/password";
    nixos.core.srv.db.mysql.user.password         = "nixos/core/srv/db/mysql/users/kilig/password";
    nixos.core.srv.db.postgresql.user.password    = "nixos/core/srv/db/postgresql/users/kilig/password";
    nixos.core.srv.db.redis.user.password         = "nixos/core/srv/db/redis/users/redis-kilig/password";
  };

  nixpkgs = {
    overlays = [ ];
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [ "python3.12-ecdsa-0.19.1" ];
    };
  };
}
