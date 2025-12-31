# @path: ~/projects/nix-config/home-manager/system/starship.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.starship.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;

    # starship.toml
    settings = {
      # global
      add_newline = false;
      command_timeout = 1000;
      scan_timeout = 10;

      # main proptm
      # format = lib.concatStrings [
      #   "$all"         # auto include shadow used module
      #   "$line_break"  # line break
      #   "$character"   # input character
      # ];
      format = ''
        $username$hostname$directory$git_branch$git_status$nix_shell$rust$python$nodejs$c$lua$package$golang$java
      '';
      # right part
      right_format = "$time$cmd_duration";

      # input character
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol   = "[✗](bold red)";
        vicmd_symbol   = "[❮](bold cyan)";  # vi mode
        format         = "$symbol\n";
      };
      # dir
      directory = {
        truncation_length = 5;
        truncation_symbol = "…/";
        style = "bold blue";
      };
      # Git
      git_branch = {
        symbol = " ";
        style = "bold purple";
        format = "[$symbol$branch]($style)";
      };
      git_status = {
        format = "[($all_status$ahead_behind)]($style)";
        style = "bold yellow";
        conflicted = "=";
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇕⇡$ahead_count⇣$behind_count";
        untracked = "?$count";
        stashed = "\\$$count";
        modified = "!$count";
        staged = "+$count";
        renamed = "»$count";
        deleted = "−$count";
      };
      # languages
      c = {
        format = ''via [$symbol$version]($style)'';
        style = "bold bright-blue";
        symbol = "🇨 ";
      };
      rust = {
        format = ''via [$symbol$version]($style)'';
        style = "bold red";
        symbol = "🦀 ";
      };
      python = {
        format = ''via [$symbol$version(\($virtualenv\))]($style)'';
        style = "yellow bold";
        symbol = "🐍 ";
      };
      nodejs = {
        format = ''via [$symbol$version]($style)'';
        style = "bold green";
        symbol = "⬢ ";
      };
      lua = {
        format = ''via [$symbol$version]($style)'';
        style = "bold blue";
        symbol = "🌙 ";
      };
      nix_shell = {
        format = ''via [$symbol$version]($style)'';
        style = "bold blue";
        symbol = "❄️ ";
      };
      # pkgs-manager(Cargo、npm、pip、etc.)
      package = {
        disabled = false;
        format = ''is [$symbol$version]($style)'';
        style = "208 bold";  # orange
        symbol = "📦 ";
      };
      # command execute time (min > 1s)
      cmd_duration = {
        min_time = 1000;  # 1s
        format = ''took [$duration]($style)'';
        style = "bold yellow";
      };
      # time (right format)
      time = {
        format = ''at [$time]($style)'';
        style = "dimmed white";
        disabled = false;
      };
      # optimite
      username = { disabled = true; };
      hostname = { disabled = true; };
      jobs = { disabled = true; };
      battery = { disabled = true; };
    };
  };
}


