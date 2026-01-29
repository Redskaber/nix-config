# @path: ~/projects/configs/nix-config/docs/example/dev/dm/c/default.nix
# @author: redskaber
# @datetime: 2026-01-29
# @description: docs::example::dev::dm::c::default
#
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, dev, ... }: {

  # (readonly)
  default = {

    buildInputs = with pkgs; [
      clang                     # Primary C compiler (recommended)
      clang-tools               # Provides clangd (LSP), clang-tidy, etc.
      glibc                     # C Libray (macos musl)
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      cmake
      ninja
    ];
    preInputsHook = ''
      echo "[preInputsHook]: example c shell!"
    '';
    postInputsHook = ''
      export CC="${pkgs.clang}/bin/clang"
      export C_INCLUDE_PATH="${pkgs.glibc.dev}/include"
      export CLANG_COLOR_DIAGNOSTICS=always
      # Optional: Symbols
      export CFLAGS=" $CFLAGS -g"
      echo "[postInputsHook]: example c shell!"
    '';

    preShellHook = ''
      echo "[preShellHook]: example c shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: example c shell!"
    '';
  };

  mini = {
    buildInputs = with pkgs; [
      clang                     # Primary C compiler (recommended)
    ];
  };


}



