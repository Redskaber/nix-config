# @path: ~/projects/configs/nix-config/docs/example/dev/dm/python/default.nix
# @author: redskaber
# @datetime: 2026-01-29
# @description: docs::example::dev::dm::python::default
#
# Modern, fast, and minimal Python dev environment using uv + ruff
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, dev, ... }: {

  # default: (readonly) : used nixos origin link
  default = {

    # Core runtime & tools
    buildInputs = with pkgs; [
      python312         # Stable, reproducible base interpreter
      uv                # Ultra-fast Python package installer & project manager
      ruff              # All-in-one linter/formatter (replaces black/isort/flake8)
      pyright           # Fast, Microsoft-backed LSP for Python
      # mypy            # Static type checker
      # Optional: keep poetry if you need its plugin ecosystem
      # poetry

      # pyright depands
      nodejs_24
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      # Add gcc if you frequently install packages with C extensions (e.g., numpy, pandas)
      # gcc
    ];

    # Not recommended used nix shellHook, lifeship is terrible.
    # env.xxx = xxx;
    preInputsHook = ''
      echo "[preInputsHook]: example python shell!"
    '';
    postInputsHook = ''
      # Speed up Python bytecode caching
      export PYTHONPYCACHEPREFIX="$PWD/.cache/python"

      # Ensure uv uses the correct Python version
      export UV_PYTHON=${pkgs.python312}/bin/python

      # Cache path uv caching
      export UV_CACHE_DIR="$PWD/.cache/uv"

      # Optional: alias for convenience (uncomment if desired)
      # alias python=python3
      # alias pip='uv pip'
      echo "[postInputsHook]: example python shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: example python shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: example python shell!"
    '';
  };

}


