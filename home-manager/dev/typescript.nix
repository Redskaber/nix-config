# @path: ~/projects/nix-config/home-manager/dev/typescript.nix
# @author: redskaber
# @datetime: 2025-12-12
# Focused TypeScript dev environment: tsc + LSP + runtime


{ pkgs, inputs, dev, mkDevShell, ... }: {
  default = mkDevShell {

    buildInputs = with pkgs; [
      nodejs_24                     # Runtime (includes npm)
      pnpm                          # Recommended package manager
      yarn                          # Alternative

      typescript                    # Global tsc (for quick checks or legacy projects)
      typescript-language-server    # Official LSP for TS/JS

      # Optional: execute TS scripts directly
      tsx                           # Fast, modern alternative to ts-node
      # ts-node                     # Traditional (slower, but widely used)
      # Optional: testing
      # vitest                      # Next-gen test runner with first-class TS support
    ];

    preInputsHook = ''
      echo "[preInputsHook]: typescript hell!"
    '';
    postInputsHook = ''
      export NODE_OPTIONS="--no-warnings"

      # Verify toolchain
      # echo "TS $(tsc --version)"
      echo "[postInputsHook]: typescript shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: typescript shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: typescript shell!"
    '';
  };
}
