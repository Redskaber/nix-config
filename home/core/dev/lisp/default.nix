# @path: ~/projects/configs/nix-config/home/core/dev/lisp/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::lisp::default
#
# modern, fast lisp development environment with sbcl + rlwrap + pkg-config
# - attrset   : (permission , scope , load      )
# - default   : (readonly   , global, default   ): minimal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language

{ pkgs, inputs, shared, dev, ... }: {
  default = {
    shell = "zsh";

    buildInputs = with pkgs; [
      # core common lisp runtime
      sbcl                      # primary common lisp implementation

      # repl / interaction
      rlwrap                    # better repl line editing/history
      clinfo                    # common lisp implementation info (optional utility)

      # build / integration helpers
      pkg-config                # for ffi/native deps discovery
      gcc                       # fallback native toolchain for ffi / compiled deps
      gnumake                   # build helper for native deps
    ];

    nativeBuildInputs = with pkgs; [
      # keep minimal; useful when some lisp libs compile native parts
      pkg-config
    ];

    preInputsHook = ''
      echo "[preInputsHook]: lisp shell!"
    '';

    postInputsHook = ''
      # common lisp runtime
      export LISP=${pkgs.sbcl}/bin/sbcl
      export SBCL_HOME="${pkgs.sbcl}/lib/sbcl"

      # optional: make sbcl the default lisp executable
      export CL="${pkgs.sbcl}/bin/sbcl"

      # development-friendly defaults
      export ASDF_OUTPUT_TRANSLATIONS="/tmp/asdf-cache/:"
      export SBCL_DISABLE_DEBUGGER="no"

      # optional native toolchain hints for ffi / c bindings
      export CC="${pkgs.gcc}/bin/gcc"

      echo "[postInputsHook]: lisp shell!"
    '';

    preShellHook = ''
      echo "[preShellHook]: lisp shell!"
    '';

    postShellHook = ''
      echo "[postShellHook]: lisp shell!"
    '';
  };
}


