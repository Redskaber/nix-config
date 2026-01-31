
# @path: ~/projects/configs/nix-config/home/core/dev/java/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::java::default
#
# Modern Java dev environment: JDK 21 + Maven/Gradle + JDT.LS
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, dev, ... }: {
  default = {

    buildInputs = with pkgs; [
      temurin-bin-21      # Eclipse Temurin JDK 21 (LTS, OpenJDK)
      maven               # Build tool
      gradle              # Build tool (alternative)
      jdt-language-server # Official Java LSP from Nixpkgs (preferred over jdt-language-server)
    ];

    nativeBuildInputs = with pkgs; [
      # Most Java tools are runtime deps, so nativeBuildInputs often empty
    ];

    preInputsHook = ''
      echo "[preInputsHook]: java shell!"
    '';
    postInputsHook = ''
      # Set JAVA_HOME correctly for Temurin
      export JAVA_HOME=${pkgs.temurin-bin-21}

      # Optional: verify
      # echo "Java $(java -version 2>&1 | head -1)"
      echo "[postInputsHook]: java shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: java shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: java shell!"
    '';

  };
}


