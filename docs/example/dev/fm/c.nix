# @path: ~/projects/configs/nix-config/docs/example/dev/fm/c.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: docs::example::dev::fm::c
#
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, ... }: {

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



