# @path: ~/projects/configs/nix-config/home/core/dev/python.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Modern, fast, and minimal Python dev environment using uv + ruff


{ pkgs, inputs, dev, ... }: {
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

      # Optional: alias for convenience (uncomment if desired)
      # alias python=python3
      # alias pip='uv pip'
      echo "[postInputsHook]: python shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: python shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: python shell!"
    '';
  };

  machine = {
    buildInputs = with pkgs; [
      # Core runtime & tooling
      python312
      uv
      ruff
      pyright

      # Scientific computing & ML stack
      # numpy
      # scipy
      # pandas
      # scikit-learn
      # matplotlib
      # seaborn
      # plotly
      # jupyter
      # ipykernel
      # tqdm
      # rich
      # polars

      # Deep learning frameworks (CPU versions from Nixpkgs)
      # tensorflow-minimal
      # pytorch

      # Hugging Face ecosystem (core packages available in Nixpkgs)
      # datasets
      # transformers

      # runtime depends (libstdc++)
      gcc.cc.lib
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      gcc  # Required for building C extensions (e.g., via uv pip install)
    ];

    preInputsHook = ''
      echo "[preInputsHook]: python ML/DL shell!"
    '';
    postInputsHook = ''
      # depends inject
      export LD_LIBRARY_PATH="${pkgs.gcc.cc.lib}/lib:$LD_LIBRARY_PATH"
      # Bytecode cache isolation
      export PYTHONPYCACHEPREFIX="$PWD/.cache/python"

      # Ensure uv uses the correct interpreter
      # Tips: don't set global uv python path
      # export UV_PYTHON=${pkgs.python312}/bin/python
      # Cacheing uv path to project
      export UV_CACHE_DIR="$PWD/.cache/uv"

      # Jupyter data directory
      export JUPYTER_DATA_DIR="$HOME/.local/share/jupyter"

      # Note: For GPU support (CUDA), install PyTorch/TensorFlow via uv using official wheels.
      # Version:
      #   https://pytorch.org/get-started/previous-versions/
      #   Chioce your version:
      #     - commnd    : nvidia-smi      -> (CUDA Version: xxx(SUPPORT_MAX_VERSION))
      #     - (Optional): nvcc --version
      #
      # Example in your project (SUPPORT_MAX_VERSION=12.2):
      #    uv add torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 \
      #      --extra-index-url https://download.pytorch.org/whl/cu121 \
      #      --index-strategy unsafe-best-match

      echo "[postInputsHook]: python ML/DL shell ready!"
    '';

    preShellHook = ''
      echo "[preShellHook]: entering ML/DL environment..."
    '';

    postShellHook = ''
      echo "Entry project:"
      echo "    uv init && uv venv && source .venv/bin/activate"
      echo "    sed -i 's/^requires-python = .*/requires-python = \">=3.12,<3.13\"/' pyproject.toml"
      echo "    uv add numpy scipy pandas scikit-learn matplotlib seaborn plotly jupyter ipykernel tqdm rich polars"
      echo "    uv add datasets transformers"
      echo "    uv add torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 \\"
      echo "        --extra-index-url https://download.pytorch.org/whl/cu121 \\"
      echo "        --index-strategy unsafe-best-match"
      echo "Direnv:"
      echo "cat > .envrc << 'EOF'"
      echo "# direnv::dot_envrc content:"
      echo "# echo \"# ############################################################################################\""
      echo "# echo \"# Remote: github:redskaber/nix-config/26c7a7731734b88d51b70599a054f0e246b52262#python-machine\""
      echo "# echo \"# commnd: direnv allow\""
      echo "# echo \"# commnd: source .venv/bin/activate\""
      echo "# echo \"# ############################################################################################\""
      echo "# use flake github:redskaber/nix-config/26c7a7731734b88d51b70599a054f0e246b52262#python-machine"
      echo "# source .venv/bin/activate"
      echo "EOF"
      echo ""
      echo "direnv allow"

      echo "[postShellHook]: ML/DL environment activated!"
    '';
  };

}

# direnv::dot_envrc content:
# echo "# ############################################################################################"
# echo "# Remote: github:redskaber/nix-config/26c7a7731734b88d51b70599a054f0e246b52262#python-machine"
# echo "# commnd: direnv allow"
# echo "# commnd: source .venv/bin/activate"
# echo "# ############################################################################################"
# use flake github:redskaber/nix-config/26c7a7731734b88d51b70599a054f0e246b52262#python-machine
# source .venv/bin/activate



