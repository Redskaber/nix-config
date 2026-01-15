# @path: ~/projects/configs/nix-config/home/core/dev/javascript.nix
# @author: redskaber
# @datetime: 2025-12-12
# @desciption: Modern JS/TS dev env: Node.js 24 + Biome + LSP


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
