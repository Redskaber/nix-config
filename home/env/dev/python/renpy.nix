# @path: ~/projects/configs/nix-config/home/env/dev/python/renpy.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::env::dev::python::renpy
#
# Modern, fast, and minimal Python dev environment using uv + ruff
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, shared, ... }: {

  # NIXPKGS_ALLOW_INSECURE=1 nix develop .#python-renpy --impure
  default = {
    shell = "zsh";
    # Core runtime & tools
    buildInputs = with pkgs; [
      python312         # Stable, reproducible base interpreter
      uv                # Ultra-fast Python package installer & project manager
      ruff              # All-in-one linter/formatter (replaces black/isort/flake8)
      pyright           # Fast, Microsoft-backed LSP for Python
      renpy             # Visual Novel Engine

      unrpa             # github package nix
      inputs.unrpyc.packages.${shared.arch.tag}.default # github package nix
      # pyright depands
      nodejs_24
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      # Add gcc if you frequently install packages with C extensions (e.g., numpy, pandas)
      # gcc
    ];

    # env.xxx = xxx;
    preInputsHook = ''
      echo "[preInputsHook]: python shell!"
    '';
    postInputsHook = ''
      # Speed up Python bytecode caching
      export PYTHONPYCACHEPREFIX="$PWD/.cache/python"

      # Ensure uv uses the correct Python version
      export UV_PYTHON=${pkgs.python312}/bin/python
      # Cache path uv caching
      export UV_CACHE_DIR="$PWD/.cache/uv"
      echo "[postInputsHook]: python shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: python shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: python shell!"
    '';
  };

}


