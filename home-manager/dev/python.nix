# @path: ~/projects/nix-config/home-manager/dev/python.nix
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

      # runtime depends
      gcc
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      gcc  # Required for building C extensions (e.g., via uv pip install)
    ];

    preInputsHook = ''
      echo "[preInputsHook]: python ML/DL shell!"
    '';
    postInputsHook = ''
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
      #   uv pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu121

      echo "[postInputsHook]: python ML/DL shell ready!"
    '';

    preShellHook = ''
      echo "[preShellHook]: entering ML/DL environment..."
    '';

    postShellHook = ''
      echo "Entry project:"
      echo "    uv init && uv venv && source .venv/bin/activate"
      echo "    uv pip install numpy scipy pandas scikit-learn matplotlib seaborn plotly jupyter ipykernel tqdm rich polars"
      echo "    uv pip install datasets transformers"
      echo "    uv pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu121"
      echo "[postShellHook]: ML/DL environment activated!"
    '';
  };

}
