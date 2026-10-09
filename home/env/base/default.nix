# @path: ~/projects/configs/nix-config/home/env/base/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::env::base::default

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  home.packages =
    with shared.upkgs;
    [
      gcc
      gdb
      cmake

      rustc
      cargo
      python314
      nodejs_26

      file
    ]
    # T4.0: Linux introspection/tracing toolbelt — meaningless or
    # unavailable on the darwin closure (dtrace/lldb own that land).
    # Dispatch-table row (enum.nix platform.trace-tools); the darwin
    # row is the Null-Object empty list, so this stays unconditional.
    ++ (shared.platform.value.trace-tools shared.upkgs);
}
