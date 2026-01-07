# @path: ~/projects/nix-config/home-manager/dev/nix.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Modern Nix development environment — aligned with RFC 109 and community best practices


{ pkgs, inputs, dev, mkDevShell, ... }: {
  default = mkDevShell {

    buildInputs = with pkgs; [
      nix                        # Core runtime (with flakes, experimental features)
      nixfmt-rfc-style           # Formatter(RFC 109): Officially endorsed formatter
      statix                     # Linter(static analysis): Detects anti-patterns, unused bindings, etc.
      deadnix                    # Dead-code-eliminayion: Removes unused definitions
      nil                        # Language-Server-Protocol: Fast, official LSP by NixOS team (supports flakes, overlays, etc.)

      # Optional but useful:
      # nix-output-monitor       # Visualize build outputs (great for CI/debugging)
      # nix-tree                 # Explore closure dependencies interactively
    ];

    nativeBuildInputs = with pkgs; [
      # Usually empty for pure Nix dev
    ];

    preInputsHook = ''
      echo "[preInputsHook]: nix hell!"
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
}

