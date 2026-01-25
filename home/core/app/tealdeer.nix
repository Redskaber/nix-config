# @path: ~/projects/configs/nix-config/home/core/app/tealdeer.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.tealdeer.enable
# description: home::core::app::tealdeer
# - tldr（Too Long; Didn't Read) is a concise,
# - practical example of use for standard Unix/Linux commands such as tar, ssh, grep, etc.
# - Compared to the lengthy and technical MAN manual,
# - TLDR shows only the most common and useful uses, making it ideal for quick daily reference.
# - ps: tldr tar

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  programs.tealdeer = {
    enable = true;
    settings = {
      display.compact = false;
      display.use_pager = true;
      updates.auto_update = true;
      updates.auto_update_interval_hours = 720;
    };
  };

}


