# @path: ~/projects/configs/nix-config/home/core/dev/nix/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::nix::default
#
# Modern Nix development environment — aligned with RFC 109 and community best practices
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, dev, ... }: {
  # base attrset
  default = {

    buildInputs = with pkgs; [
      nix                        # Core runtime (with flakes, experimental features)
      nixfmt-rfc-style           # Formatter(RFC 109): Officially endorsed formatter
      statix                     # Linter(static analysis): Detects anti-patterns, unused bindings, etc.
      alejandra                  # Format specifications
      deadnix                    # Dead-code-eliminayion: Removes unused definitions
      nil                        # Language-Server-Protocol: Fast, official LSP by NixOS team (supports flakes, overlays, etc.)
      nvd                        # Nix/NixOS package version diff tool

      # vulnix                     # NixOS vulnerability scanner (need python env)

      # Optional but useful:
      # nix-output-monitor       # Visualize build outputs (great for CI/debugging)
      # nix-tree                 # Explore closure dependencies interactively
    ];

    nativeBuildInputs = with pkgs; [
      # Usually empty for pure Nix dev
    ];

    preInputsHook = ''
      echo "[preInputsHook]: nix shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: nix shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: nix shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: nix shell!"
    '';

  };

  derivation-free-security = {
    combiFrom = [
      dev.derivation.free
    ];

    # extras
    buildInputs = with pkgs; [
      python312                  # python enviroment
      vulnix                     # NixOS vulnerability scanner (need python env)
    ];

  };

}


