# @path: ~/projects/configs/nix-config/lib/shared/core.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: lib::shared::core
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - nix core informations configuration

{ nixpkgs, ... }:
let
  enum = {
    pair = { first, second }: { inherit first second; };
    platform = {
      min   = enum.pair { first=0; second="Unknown";};
      linux = enum.pair { first=0; second="linux";  };
      macos = enum.pair { first=1; second="macos";  };
      nixos = enum.pair { first=2; second="nixos";  };
      wsl   = enum.pair { first=3; second="wsl";    };
      max   = enum.pair { first=3; second="Unknown";};
    };
    arch = {
      min             = enum.pair { first=0; second="Unknown";        };
      aarch64-darwin  = enum.pair { first=0; second="aarch64-darwin"; };
      aarch64-linux   = enum.pair { first=1; second="aarch64-linux";  };
      i686-linux      = enum.pair { first=2; second="i686-linux";     };
      x86_64-darwin   = enum.pair { first=3; second="x86_64-darwin";  };
      x86_64-linux    = enum.pair { first=4; second="x86_64-linux";   };
      max             = enum.pair { first=4; second="Unknown";        };
    };
    window-manager = {
      min       = enum.pair { first=0; second="Unknown";  };
      gnome     = enum.pair { first=0; second="gnome";    };
      hyprland  = enum.pair { first=1; second="hyprland"; };
      niri      = enum.pair { first=2; second="niri";     };
      max       = enum.pair { first=2; second="Unknown";  };
    };
    drive = {
      min           = enum.pair { first=0; second="Unknown";      };
      amd           = enum.pair { first=0; second="amd";          };
      intel         = enum.pair { first=1; second="intel";        };
      nvidia        = enum.pair { first=2; second="nvidia";       };
      nvidia-prime  = enum.pair { first=3; second="nvidia-prime"; };
      max           = enum.pair { first=3; second="Unknown";      };
    };
  };

  # enum.platform
  fn-is_supported_platform = platform:
    platform.first >= enum.platform.min.first
    && platform.first <= enum.platform.max.first;

  fn-get_platform_name = platform:
    if (fn-is_supported_platform platform) then platform.second
    else throw ''
      [ERROR] Unsupported platform: ${platform.second}
      Supported platforms: ${builtins.concatStringsSep ", " (builtins.attrNames enum.platform)}
    '';

  # enum.arch
  fn-is_supported_arch = arch:
    arch.first >= enum.arch.min.first
    && arch.first <= enum.arch.max.first;

  fn-get_arch_name = arch:
    if (fn-is_supported_arch arch) then arch.second
    else throw ''
      [ERROR] Unsupported Arch: ${arch.second}
      Supported arch: ${builtins.concatStringsSep ", " (builtins.attrNames enum.arch)}
    '';

  # enum.window-manager
  fn-is_supported_wm = wm:
    wm.first >= enum.window-manager.min.first
    && wm.first <= enum.window-manager.max.first;

  fn-get_wm_name = wm:
    if (fn-is_supported_wm wm) then wm.second
    else throw ''
      [ERROR] Unsupported Window-Manager: ${wm.second}
      Supported Window-Manager: ${builtins.concatStringsSep ", " (builtins.attrNames enum.window-manager)}
    '';

  # enum.drive
  fn-is_supported_drive = drive:
    drive.first >= enum.drive.min.first
    && drive.first <= enum.drive.max.first;

  fn-get_drive_name = drive:
    if (fn-is_supported_drive drive) then drive.second
    else throw ''
      [ERROR] Unsupported drive: ${drive.second}
      Supported drive: ${builtins.concatStringsSep ", " (builtins.attrNames enum.drive)}
    '';

  arch = enum.arch;
  drive = enum.drive;
  platform = enum.platform;
  window-manager = enum.window-manager;
  pkgs = nixpkgs.legacyPackages.${arch.x86_64-linux.second};  # jocker pkgs
  version = "25.11";
in {
  inherit
    enum arch drive platform window-manager version pkgs
    fn-is_supported_platform  fn-get_platform_name
    fn-is_supported_arch      fn-get_arch_name
    fn-is_supported_wm        fn-get_wm_name
    fn-is_supported_drive     fn-get_drive_name;
}


