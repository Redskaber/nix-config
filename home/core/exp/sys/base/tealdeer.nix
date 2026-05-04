# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/tealdeer.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::tealdeer
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.tealdeer.enable
# - tldr（Too Long; Didn't Read) is a concise,
# - practical example of use for standard Unix/Linux commands such as tar, ssh, grep, etc.
# - Compared to the lengthy and technical MAN manual,
# - TLDR shows only the most common and useful uses, making it ideal for quick daily reference.
# - ps: tldr tar

{ inputs
, shared
, lib
, config
, pkgs
, ...
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


