# @path: ~/projects/configs/nix-config/home/core/exp/sys/monitor/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @diractory: home::core::exp::sys::monitor::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./bottom.nix
    ./btop.nix
    ./htop.nix
  ];

}


