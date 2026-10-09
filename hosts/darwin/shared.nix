# @path: ~/projects/nix-config/hosts/darwin/shared.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: hosts::darwin::shared — darwin host policy overrides (T3.2)
#
# The darwin host of the multi-host design (T3.2): policy-declared as
# platform.tag = "darwin", which the flake dispatch routes into
# darwinConfigurations (nix-darwin + home-manager module mode). The
# class flip ALSO retargets the runtime pkgs instance — arch.tag is
# what lib/shared/runtime imports nixpkgs with, so overriding it here
# gives this host an aarch64-darwin package set without touching the
# loader (strategy carried by data, again).

{ shared, inputs, ... }:
{
  # Class flip: this host is a darwin machine.
  platform = shared.enum.platform.darwin;

  # Apple Silicon.
  arch = shared.enum.arch.aarch64-darwin;

  # Aqua is the window manager; no Linux WM stack on this host.
  window-manager = shared.enum.window-manager.none;

  # Lean, terminal-shaped machine.
  editor-set = shared.enum.editor-set.minimal;
  terminal-set = shared.enum.terminal-set.kitty-only;
  browser-set = shared.enum.browser-set.cli-only;
  # Terminal-shaped laptop (T5.10): the triad + document/reading/RE
  # trees stay (cross-platform tooling); desktop entertainment trees
  # don't. Pre-T5.10 the closure carried the whole app grab-bag —
  # 126 home.packages including linux-only blobs (wps-office).
  app-set = shared.enum.app-set.lean;

  # Headless-from-WSL-style minimal services (no db stack on a laptop).
  service-profile = shared.enum.service-profile.minimal;
}
