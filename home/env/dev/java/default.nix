# @path: ~/projects/configs/nix-config/home/env/dev/java/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::env::dev::java::default
#
# Modern Java dev environment: JDK 21 + Maven/Gradle + JDT.LS
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, shared, dev, ... }: {
  default = {
    shell = "zsh";
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


