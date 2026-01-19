# @path: ~/projects/configs/nix-config/home/core/sys/fish.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: home::core::sys::fish
# - https://nix-community.github.io/home/options.xhtml#opt-programs.fish.enable
# @depends: eza, zoxide, fzf, fisher, bat, ripgrep

{ inputs
, config
, lib
, pkgs
, ...
}:
let
  fish_path = "${config.home.profileDirectory}/bin/fish";
in
{
  programs.fish = {
    enable = true;
    package = pkgs.fish;
    preferAbbrs = true;
    generateCompletions = true;

    # session variables
    shellInit = ''
      set -gx EDITOR nvim
      set -gx VISUAL nvim
      set -gx PAGER less
    '';

    # alias
    shellAliases = {
      ls = "eza --icons=always";
      ll = "eza -l --icons=always";
      la = "eza -la --icons=always";
      lt = "eza --tree --icons=always";
      # grep = "rg";
      # cat = "bat";
      # top = "btm";
      vi = "nvim";
      nde = "nvim ./.envrc";
    };

    # inputs auto expr
    shellAbbrs = {
      g = "git";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline";
      j = "z";  # zoxide
      v = "nvim";
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    # (fisher env)
    plugins = [
      { name = "autopair"; src = pkgs.fishPlugins.autopair; }
      { name = "fzf-fish"; src = pkgs.fishPlugins.fzf-fish; }
    ];

    functions = {
      # quick build .gitignore
      gitignore = "curl -sL https://www.gitignore.io/api/$argv";
    };
    completions = {
      eza = ''
        complete -c eza -s l -l long --description "Long listing format"
        complete -c eza -s a -l all --description "Show hidden files"
        complete -c eza -s T -l tree --description "Show directory tree"
        complete -c eza --description "Modern replacement for ls"
      '';
    };

    # repl init（fzf,etc.)
    interactiveShellInit = ''
      # Initialize fzf if available
      if type -q fzf
        set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
        set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
      end

      # Ensure zoxide is initialized
      if type -q zoxide
        zoxide init fish | source
      end
    '';
  };

  # fish: /etc/shells (chsh)
  home.activation.ensure_fish_in_shells = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x ${fish_path} ]; then
      if ! grep -Fxq '${fish_path}' /etc/shells; then
        echo "⚠️ Fish is installed but not in /etc/shells."
        echo "   To use 'chsh -s ${fish_path}', run the following as root:"
        echo "     echo '${fish_path}' | sudo tee -a /etc/shells"
        echo ""
      else
        verboseEcho "'${fish_path}' already present in /etc/shells"
      fi
    else
      verboseEcho "Warning: ${fish_path} not found - skipping /etc/shells check"
    fi
  '';
}


