# @path: ~/projects/nix-config/home-manager/dev/java.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Modern Java dev environment: JDK 21 + Maven/Gradle + JDT.LS


{ pkgs, inputs, ... }: {
  default = pkgs.mkShell {
    buildInputs = with pkgs; [
      temurin-bin-21      # Eclipse Temurin JDK 21 (LTS, OpenJDK)
      maven               # Build tool
      gradle              # Build tool (alternative)
      jdt-language-server # Official Java LSP from Nixpkgs (preferred over jdt-language-server)
    ];

    nativeBuildInputs = with pkgs; [
      # Most Java tools are runtime deps, so nativeBuildInputs often empty
    ];

    shellHook = ''
      # Set JAVA_HOME correctly for Temurin
      export JAVA_HOME=${pkgs.temurin-bin-21}

      # Optional: verify
      # echo "Java $(java -version 2>&1 | head -1)"
    '';
  };
}
