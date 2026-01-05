# @path: ~/projects/nix-config/home-manager/dev/rust.nix
# @author: redskaber
# @datetime: 2025-12-12

{ pkgs, inputs, ... }: {
  default = pkgs.mkShell {
    buildInputs = with pkgs; [
      cargo rustc rustfmt clippy rust-analyzer
      # (explicit optional) depends
      glib
    ];
    # (explicit optional) build depends packages config inject
    nativeBuildInputs = [ pkgs.pkg-config ];
    # env.RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
    shellHook = ''
      export RUST_SRC_PATH=${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}
    '';
  };
}

