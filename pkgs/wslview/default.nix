# @path: ~/projects/configs/nix-config/pkgs/wslview/default.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: pkgs::wslview — minimal "open on the Windows side" shim (T3.1)
# @directory: https://learn.microsoft.com/en-us/windows/wsl/
#
# wslu was removed from nixpkgs (upstream archived). The one piece this
# tree actually consumes from it is wslview(1) — hand a URL/file to the
# Windows default handler. This shim reproduces exactly that contract
# with a two-line PowerShell call, no dependencies, no daemon:
#
#   wslview https://example.com     → opens in the default Windows browser
#   wslview ./report.pdf           → opens in the default Windows viewer
#
# Design notes (compiler-pipeline view): the package is a leaf node with
# a stable CLI surface — when nixpkgs ever re-adds a maintained helper,
# swapping the body of THIS derivation swaps it for every consumer
# without touching platform/wsl again.

{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "wslview";
  version = "1.0.0";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cat > "$out/bin/wslview" <<'EOF'
    #!/bin/sh
    # wslview — open a URL/file/path on the Windows side (WSL2 interop).
    # Contract-compatible subset of wslu's wslview(1).
    set -eu
    target="''${1:-.}"
    # Convert WSL paths (/mnt/c/… or /home/…) so Windows can resolve them.
    case "$target" in
      /*) winpath=$(wslpath -w "$target" 2>/dev/null || printf '%s' "$target") ;;
      *)  winpath="$target" ;;
    esac
    exec /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
      -NoProfile -NonInteractive -Command "Start-Process -FilePath '$winpath'"
    EOF
    chmod +x "$out/bin/wslview"

    runHook postInstall
  '';

  meta = {
    description = "Minimal wslview(1) replacement — Windows-side file/URL opener for WSL2";
    longDescription = ''
      Drop-in for the archived wslu's wslview: resolves a WSL path to its
      Windows form (wslpath -w) and hands it to PowerShell Start-Process,
      which opens it with the Windows default handler.
    '';
    platforms = lib.platforms.linux;
    mainProgram = "wslview";
  };
}
