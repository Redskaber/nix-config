# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/ripgrep.nix
# @author: redskaber
# @datetime: 2026-10-12
# @description: nmt::home::core::exp::sys::base::ripgrep
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval)
#
# programs.ripgrep.arguments → ~/.config/ripgrep/ripgreprc, one flag per
# line, plain text (no pkgs.formats.* involved — no scrubbing issue).
#
# This member is the CONSUMER-LEVEL REGRESSION PROOF for the fork's
# `--` end-of-options guards (pinned rev 25fe4c8): every needle below
# starts with a dash — under the pre-guard fork, grep parsed
# "--smart-case" as a flag (an error at best; "-x"-class needles could
# be eaten as REAL grep flags and silently test the wrong thing), and
# this assertion could not exist. The fork's own battery locks the
# guards in isolation; this member locks them through the fleet's real
# needle flow (tests/nmt/default.nix `contains` → escapeShellArg →
# assertFileContains → grep -qF --).

{
  inputs,
  shared,
  lib,
  ...
}:

lib.nmt.buildHomeManagerTest {
  description = "ripgrep: rcfile flags written";

  modules = [
    {
      home = {
        username = "testuser";
        homeDirectory = "/home/testuser";
        stateVersion = "${shared.version.value.stateVersion}";
      };

      programs.ripgrep = {
        enable = true;
        arguments = [
          "--smart-case"
          "--colors=auto"
        ];
      };
    }
  ];

  tests = {
    "ripgrep: rcfile exists" = {
      path = ".config/ripgrep/ripgreprc";
      exists = true;
    };

    "ripgrep: --smart-case flag written (leading-dash needle)" = {
      path = ".config/ripgrep/ripgreprc";
      contains = [ "--smart-case" ];
    };

    "ripgrep: --colors=auto flag written (leading-dash needle)" = {
      path = ".config/ripgrep/ripgreprc";
      contains = [ "--colors=auto" ];
    };
  };
}
