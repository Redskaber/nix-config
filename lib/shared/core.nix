# @path: ~/projects/configs/nix-config/lib/shared/core.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: lib::shared::core
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - nix core informations configuration

{ nixpkgs, ... }:
let
  const = {
    devDir  = "home/core/dev";
    hostName= "nixos";
    user    = {
      username          = "example";
      shell             = "zsh";
      openssh-authKeys  = [ ];
    };
    git     = {
      defaultBranch     = "main";
      name              = "example";
      email             = "example@gmail.com";
      lazygit.name      = "lg";
    };
    rbw     = {
      email             = "example@gmail.com";
      lock_timeout      = 1000;
    };
    time    = {
      used-ip-timeZone  = false;
      timeZone          = "Asia/Shanghai";
    };
    secrets = {
      user-password             = "nixos.core.base.users.kilig.password";
      nixos-github-git-visited  = "nixos.core.base.nix.kilig.nixos-github-git-visited";
      mongodb-user-password     = "nixos.core.srv.db.mongodb.users.kilig.password";
      mysql-root-password       = "nixos.core.srv.db.mysql.users.root.password";
      mysql-user-password       = "nixos.core.srv.db.mysql.users.kilig.password";
      postgresql-user-password  = "nixos.core.srv.db.postgresql.users.kilig.password";
      redis-user-password       = "nixos.core.srv.db.redis.users.redis-kilig.password";
    };
    nixpkgs = {
      overlays  = [ ];
      config    = {
        allowUnfree               = true;
        permittedInsecurePackages = [ ];
      };
    };
  };

  enum = {
    editor = {
      vim     = struct.variant { index=0; value="vim";      };
      nvim    = struct.variant { index=1; value="nvim";     };
      code    = struct.variant { index=2; value="code";     };
      zeditor = struct.variant { index=3; value="zeditor";  };
      __min   = struct.variant { index=0; value="Unknown";  };
      __max   = struct.variant { index=3; value="Unknown";  };
      default = enum.editor.nvim;
    };
    version = {
      v25_11  = struct.variant { index=0; value="25.11";    };
      __min   = struct.variant { index=0; value="Unknown";  };
      __max   = struct.variant { index=0; value="Unknown";  };
      default = enum.version.v25_11;
    };
    platform = {
      linux   = struct.variant { index=0; value="linux";    };
      macos   = struct.variant { index=1; value="macos";    };
      nixos   = struct.variant { index=2; value="nixos";    };
      wsl     = struct.variant { index=3; value="wsl";      };
      __min   = struct.variant { index=0; value="Unknown";  };
      __max   = struct.variant { index=3; value="Unknown";  };
      default = enum.platform.nixos;
    };
    arch = {
      aarch64-darwin  = struct.variant { index=0; value="aarch64-darwin"; };
      aarch64-linux   = struct.variant { index=1; value="aarch64-linux";  };
      i686-linux      = struct.variant { index=2; value="i686-linux";     };
      x86_64-darwin   = struct.variant { index=3; value="x86_64-darwin";  };
      x86_64-linux    = struct.variant { index=4; value="x86_64-linux";   };
      __min           = struct.variant { index=0; value="Unknown";        };
      __max           = struct.variant { index=4; value="Unknown";        };
      default         = enum.arch.x86_64-linux;
    };
    window-manager = {
      gnome     = struct.variant { index=0; value="gnome";    };
      hyprland  = struct.variant { index=1; value="hyprland"; };
      niri      = struct.variant { index=2; value="niri";     };
      __min     = struct.variant { index=0; value="Unknown";  };
      __max     = struct.variant { index=2; value="Unknown";  };
      default   = enum.window-manager.hyprland;
    };
    drive = {
      amd           = struct.variant { index=0; value="amd";          };
      intel         = struct.variant { index=1; value="intel";        };
      nvidia        = struct.variant { index=2; value="nvidia";       };
      nvidia-prime  = struct.variant { index=3; value="nvidia-prime"; };
      __min         = struct.variant { index=0; value="Unknown";      };
      __max         = struct.variant { index=3; value="Unknown";      };
      default       = enum.drive.intel;
    };
  };

  struct = {
    variant = { index, ... } @return_variant: return_variant;

    user = {
      username          ? const.user.username,
      shell             ? const.user.shell,
      openssh-authKeys  ? const.user.openssh-authKeys,
    } @return_user: return_user;

    git = {
      defaultBranch     ? const.git.defaultBranch,
      name              ? const.git.name,
      email             ? const.git.email,
      lazygit           ? const.git.lazygit,
    } @return_git: return_git;

    rbw = {
      email             ? const.rbw.email,
      lock_timeout      ? const.rbw.lock_timeout,
    } @return_rbw: return_rbw;

    time = {
      used-ip-timeZone  ? const.time.used-ip-timeZone,
      timeZone          ? const.time.timeZone,
    } @return_time: return_time;

    secrets = {
      user-password             ? const.secrets.user-password,
      nixos-github-git-visited  ? const.secrets.nixos-github-git-visited,
      mongodb-user-password     ? const.secrets.mongodb-user-password,
      mysql-root-password       ? const.secrets.mysql-root-password,
      mysql-user-password       ? const.secrets.mysql-user-password,
      postgresql-user-password  ? const.secrets.postgresql-user-password,
      redis-user-password       ? const.secrets.redis-user-password,
    } @return_secrets: return_secrets;

    nixpkgs_config = {
      allowUnfree               ? true,
      permittedInsecurePackages ? [],
    } @return_nixpkgs_config: return_nixpkgs_config;

    nixpkgs = {
      overlays        ? [ ],
      config          ? struct.nixpkgs_config,
    } @return_nixpkgs: return_nixpkgs;

    shared = {
      arch            ? enum.arch.default,
      drive           ? enum.drive.default,
      platform        ? enum.platform.default,
      window-manager  ? enum.window-manager.default,
      version         ? enum.version.default,
      editor          ? enum.editor.default,
      devDir          ? const.devDir,
      hostName        ? const.hostName,
      user            ? struct.user,
      git             ? struct.git,
      rbw             ? struct.rbw,
      time            ? struct.time,
      secrets         ? struct.secrets,
      nixpkgs         ? struct.nixpkgs,
      ...
    } @return_shared: return_shared;
  };

  # enum.editor
  fn-is_supported_editor = editor:
    editor.index >= enum.editor.min.index
    && editor.index <= enum.editor.max.index;

  fn-get_editor_name = editor:
    if (fn-is_supported_editor editor) then editor.value
    else throw ''
      [ERROR] Unsupported editor: ${editor.value}
      Supported editors: ${builtins.concatStringsSep ", " (builtins.attrNames enum.editor)}
    '';

  # enum.version
  fn-is_supported_version = version:
    version.index >= enum.version.min.index
    && version.index <= enum.version.max.index;

  fn-get_version_name = version:
    if (fn-is_supported_version version) then version.value
    else throw ''
      [ERROR] Unsupported version: ${version.value}
      Supported versions: ${builtins.concatStringsSep ", " (builtins.attrNames enum.version)}
    '';

  # enum.platform
  fn-is_supported_platform = platform:
    platform.index >= enum.platform.min.index
    && platform.index <= enum.platform.max.index;

  fn-get_platform_name = platform:
    if (fn-is_supported_platform platform) then platform.value
    else throw ''
      [ERROR] Unsupported platform: ${platform.value}
      Supported platforms: ${builtins.concatStringsSep ", " (builtins.attrNames enum.platform)}
    '';

  # enum.arch
  fn-is_supported_arch = arch:
    arch.index >= enum.arch.min.index
    && arch.index <= enum.arch.max.index;

  fn-get_arch_name = arch:
    if (fn-is_supported_arch arch) then arch.value
    else throw ''
      [ERROR] Unsupported Arch: ${arch.value}
      Supported arch: ${builtins.concatStringsSep ", " (builtins.attrNames enum.arch)}
    '';

  # enum.window-manager
  fn-is_supported_wm = wm:
    wm.index >= enum.window-manager.min.index
    && wm.index <= enum.window-manager.max.index;

  fn-get_wm_name = wm:
    if (fn-is_supported_wm wm) then wm.value
    else throw ''
      [ERROR] Unsupported Window-Manager: ${wm.value}
      Supported Window-Manager: ${builtins.concatStringsSep ", " (builtins.attrNames enum.window-manager)}
    '';

  # enum.drive
  fn-is_supported_drive = drive:
    drive.index >= enum.drive.min.index
    && drive.index <= enum.drive.max.index;

  fn-get_drive_name = drive:
    if (fn-is_supported_drive drive) then drive.value
    else throw ''
      [ERROR] Unsupported drive: ${drive.value}
      Supported drive: ${builtins.concatStringsSep ", " (builtins.attrNames enum.drive)}
    '';

  fn-init-secrets = username:
    struct.secrets {
      user-password             = "nixos.core.base.users.${username}.password";
      nixos-github-git-visited  = "nixos.core.base.nix.${username}.nixos-github-git-visited";
      mongodb-user-password     = "nixos.core.srv.db.mongodb.users.${username}.password";
      mysql-root-password       = "nixos.core.srv.db.mysql.users.root.password";
      mysql-user-password       = "nixos.core.srv.db.mysql.users.${username}.password";
      postgresql-user-password  = "nixos.core.srv.db.postgresql.users.${username}.password";
      redis-user-password       = "nixos.core.srv.db.redis.users.redis-${username}.password";
    };

  arch = enum.arch;
  drive = enum.drive;
  editor = enum.editor;
  platform = enum.platform;
  version = enum.version;
  window-manager = enum.window-manager;
  secrets = struct.secrets;
  pkgs = nixpkgs.legacyPackages.${arch.x86_64-linux.value};  # jocker pkgs
in {
  inherit
    enum arch drive editor platform version window-manager
    struct secrets
    pkgs
    fn-is_supported_editor    fn-get_editor_name
    fn-is_supported_version   fn-get_version_name
    fn-is_supported_platform  fn-get_platform_name
    fn-is_supported_arch      fn-get_arch_name
    fn-is_supported_wm        fn-get_wm_name
    fn-is_supported_drive     fn-get_drive_name
    fn-init-secrets;
}


