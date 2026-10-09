# @path: ~/projects/configs/nix-config/home/core/exp/sys/monitor/btop.nix
# @author: redskaber
# @datetime: 2026-01-10
# @description: home::core::sys::btop

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.btop = {
    enable = true;
    # T4.0: package selection is platform dispatch — the dispatch table
    # (enum.nix platform rows) carries the strategy (GPU-stack build for
    # the Linux family, stock for darwin). This leaf just applies the
    # resolved strategy; version.wine/swww set the precedent.
    package = shared.platform.value.btop pkgs;
    settings = {
      vim_keys = true;
      rounded_corners = true;
      proc_tree = true;
      show_gpu_info = "on";
      show_uptime = true;
      show_coretemp = true;
      cpu_sensor = "auto";
      show_disks = true;
      only_physical = true;
      io_mode = true;
      io_graph_combined = false;
    };
  };

}
