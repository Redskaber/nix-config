# @path: ~/projects/configs/nix-config/home/core/dev/typescript/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::typescript::default
#
# Focused TypeScript dev environment: tsc + LSP + runtime
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, dev, ... }: {
  default = {

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
      echo "[preInputsHook]: typescript shell!"
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


