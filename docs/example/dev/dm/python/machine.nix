# @path: ~/projects/configs/nix-config/docs/example/dev/dm/python/machine.nix
# @author: redskaber
# @datetime: 2026-01-29
# @description: docs::example::dev::dm::python::machine
#
# Modern, fast, and minimal Python dev environment using uv + ruff
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, ... }: {

  default = {
    buildInputs = with pkgs; [
      # Core runtime & tooling
      python312
      uv
      ruff
      pyright

      # Don't used nix install all depends
      # Used your uv or poetry etc manager.
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
      gcc.cc.lib     # ML(optional other)
      nodejs_24      # pyright need (optional other)
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      gcc  # Required for building C extensions (e.g., via uv pip install)
    ];

    # Not recommended used nix shellHook, lifeship is terrible.
    preInputsHook = ''
      echo "[preInputsHook]: example python ML/DL shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: example python ML/DL shell ready!"
    '';

    preShellHook = ''
      echo "[preShellHook]: example entering ML/DL environment..."
    '';

    postShellHook = ''
      echo "[postShellHook]: example ML/DL environment activated!"
    '';
  };

}


