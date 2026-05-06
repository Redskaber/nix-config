# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::default

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ./yazi

    ./atuin.nix
    ./bat.nix
    ./cliphist.nix
    ./commitizen.nix
    ./commitlint.nix
    ./curl.nix
    ./direnv.nix
    ./eza.nix
    ./fastfetch.nix
    ./fd.nix
    ./fzf.nix
    ./git-filter-repo.nix
    ./git.nix
    ./husky.nix
    ./jq.nix
    ./just.nix
    ./rbw.nix
    ./ripgrep.nix
    ./starship.nix
    ./tealdeer.nix
    ./tmux.nix
    ./wget.nix
    ./wl-clip-persist.nix
    ./wl-clipboard.nix
    ./yq.nix
    ./zoxide.nix
  ];


}


