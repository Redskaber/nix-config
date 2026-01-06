# @path: ~/projects/nix-config/home-manager/dev/rust.nix
# @author: redskaber
# @datetime: 2025-12-12
# @desciption: Minimal, reproducible Rust development environment using nixpkgs' stable Rust toolchain.
# Fully offline-capable and suitable for flakes-based workflows.


{ pkgs, inputs, common, mkDevShell, ... }: {
  default = mkDevShell {
    inheritFrom = [ common ];

    # Core Rust toolchain (stable, from nixpkgs)
    buildInputs = with pkgs; [
      rustc                # Rust compiler
      cargo                # Package manager & build tool
      rustfmt              # Code formatter (RFC-compliant)
      clippy               # Linter for best practices and correctness
      rust-analyzer        # Official LSP server (used by VS Code, Neovim, etc.)
      # Optional debugging tools:
      # lldb              # LLVM debugger (lightweight alternative to gdb)
      # gdb               # GNU debugger (for advanced debugging)
    ];

    # Build dependencies for crates that use C/C++ libraries (e.g., via bindgen)
    nativeBuildInputs = with pkgs; [
      pkg-config
      # Add system libraries if needed (e.g., openssl, libusb):
      # openssl.dev
    ];

    # Required for rust-analyzer to provide stdlib navigation and hover docs
    # env.RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
    postInputsHook = ''
      export RUST_SRC_PATH="${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}"
    '';
  };
}

