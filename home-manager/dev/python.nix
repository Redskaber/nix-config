# @path: ~/projects/nix-config/home-manager/dev/python.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Modern, fast, and minimal Python dev environment using uv + ruff


{ pkgs, inputs, common, mkDevShell, ... }: {
  default = mkDevShell {
    inheritFrom = [ common ];

    # Core runtime & tools
    buildInputs = with pkgs; [
      python312         # Stable, reproducible base interpreter
      uv                # Ultra-fast Python package installer & project manager
      ruff              # All-in-one linter/formatter (replaces black/isort/flake8)
      pyright           # Fast, Microsoft-backed LSP for Python
      # mypy            # Static type checker
      # Optional: keep poetry if you need its plugin ecosystem
      # poetry
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      # Add gcc if you frequently install packages with C extensions (e.g., numpy, pandas)
      # gcc
    ];

    # env.xxx = xxx;
    postInputsHook = ''
      # Speed up Python bytecode caching
      export PYTHONPYCACHEPREFIX="$HOME/.cache/python"

      # Ensure uv uses the correct Python version
      export UV_PYTHON=${pkgs.python312}/bin/python

      # Optional: alias for convenience (uncomment if desired)
      # alias python=python3
      # alias pip='uv pip'
    '';
  };
}
