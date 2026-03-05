# @path: ~/projects/configs/nix-config/lib/shared/core.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: lib::shared::core
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - nix core informations configuration

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
  };

  # enum.platform
  fn-is_supported_platform = platform:
    platform.first >= enum.platform.min.first
    && platform.first <= enum.platform.max.first;

  fn-get_hostname = platform:
    if (fn-is_supported_platform platform) then platform.second
    else throw ''
      [ERROR] Unsupported platform: ${platform.second}
      Supported platforms: ${builtins.concatStringsSep ", " (builtins.attrNames enum.platform)}
    '';

  # enum.arch
  fn-is_supported_arch = arch:
    arch.first >= enum.arch.min.first
    && arch.first <= enum.arch.max.first;

  fn-get_archname = arch:
    if (fn-is_supported_arch arch) then arch.second
    else throw ''
      [ERROR] Unsupported Arch: ${arch.second}
      Supported arch: ${builtins.concatStringsSep ", " (builtins.attrNames enum.arch)}
    '';

  arch = enum.arch;
  platform = enum.platform;
  version = "25.11";
in {
  inherit
    enum arch platform version
    fn-is_supported_platform fn-get_hostname
    fn-is_supported_arch fn-get_archname;
}


