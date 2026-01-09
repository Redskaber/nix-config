# @path: ~/projects/configs/nix-config/home-manager/dev/lua.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Modern Lua dev environment for Neovim/plugins/scripting
#
# Note: Lua 5.5 was released in Dec 2025 (https://www.lua.org/manual/5.5/)
#       but is not yet available in nixpkgs as of early 2026.
#       We use Lua 5.4 which is stable, well-supported, and sufficient for
#       Neovim plugin development and general scripting.


{ pkgs, inputs, dev, ... }: {
  default = {

    buildInputs = with pkgs; [
      lua54Packages.lua     # Standard Lua 5.4 (for general scripting)
      luajit                # LuaJIT 2.1 (Lua 5.1 compatible, used by Neovim)
      luarocks              # Package manager (use with caution in Nix env)
      lua-language-server   # LSP (sumneko) — supports both Lua 5.1 and 5.4
      stylua                # Formatter (opinionated, fast, widely adopted)
    ];

    nativeBuildInputs = with pkgs; [
      # pkg-config          # Only needed if building C-based Lua modules
    ];

    preInputsHook = ''
      echo "[preInputsHook]: lua shell!"
    '';
    postInputsHook = ''
      # Set up Lua paths for lua54
      export LUA_PATH="./?.lua;${pkgs.lua54Packages.lua}/share/lua/5.4/?.lua;;"
      export LUA_CPATH="./?.so;${pkgs.lua54Packages.lua}/lib/lua/5.4/?.so;;"

      # Optional: configure luarocks to avoid global writes
      export LUAROCKS_CONFIG=/dev/null  # Disable global config
      # Or point to a local tree:
      # mkdir -p ./.luarocks
      # export LUAROCKS_PREFIX=$PWD/.luarocks

      # echo "Lua dev env ready: lua54 + luajit + LSP + stylua"
      echo "[postInputsHook]: lua shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: lua shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: lua shell!"
    '';


  };
}
