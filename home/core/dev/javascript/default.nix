# @path: ~/projects/configs/nix-config/home/core/dev/javascript/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::javascript::default
#
# Modern JS/TS dev env: Node.js 24 + Biome + LSP
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, dev, ... }: {
  default = {

    buildInputs = with pkgs; [
      nodejs_24               # LTS-ish (Node 24 is current active release)
      yarn                    # Yarn Classic or Berry
      pnpm                    # Fast, disk-efficient package manager

      typescript-language-server  # LSP for JS/TS (works with Neovim/VS Code)

      # Choose ONE formatting/linting stack:
      # Option A: Modern all-in-one (recommended)
      biome                   # Lint, format, check, organize — replaces ESLint+Prettier
      # Option B: Traditional (uncomment if needed)
      # eslint
      # prettier
    ];

    preInputsHook = ''
      echo "[preInputsHook]: javascript shell!"
    '';
    postInputsHook = ''
      # Suppress Node.js experimental warnings (e.g., from ESM loaders)
      export NODE_OPTIONS="--no-warnings"

      # Optional: set javascript package manager
      # alias ni="pnpm install"
      # alias nr="pnpm run"
      echo "[postInputsHook]: javascript shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: javascript shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: javascript shell!"
    '';

  };
}
