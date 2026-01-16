# @path: ~/projects/configs/nix-config/home/core/sys/btop.nix
# @author: redskaber
# @datetime: 2026-01-10
# @description: Atuin — Magical shell history with sync, search & stats


{ config
, lib
, pkgs
, ...
}:
{
  programs.btop = {
    enable = true;
    package = pkgs.btop.override {
      rocmSupport = true;
      cudaSupport = true;
    };
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



