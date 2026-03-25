set shell := [ "bash", "-c" ]


# ==============================================================================
# devenv
# ==============================================================================
devenv-create-all:            # Create all development environments (including combined environments).
  @just devenv-create       c
  @just devenv-create       cpp
  @just devenv-create       default
  @just devenv-create       go
  @just devenv-create       java
  @just devenv-create       javascript
  @just devenv-create       lua
  @just devenv-create       nix
  @just devenv-create-from  nix derivation-free
  @just devenv-create-from  nix derivation-unfree
  @just devenv-create-from  nix derivation-free-security
  @just devenv-create       python
  @just devenv-create-from  python renpy
  @just devenv-create       re
  @just devenv-create       rust
  @just devenv-create       typescript
  @just devenv-create       zig

devenv-create lang:             # Create a specified locale (e.g., just devenv-create rust).
  mkdir -p                      $HOME/.local/state/nix/profiles/dev/{{lang}}
  nix develop                   .#{{lang}}  --profile $home/.local/state/nix/profiles/dev/{{lang}}/kilig-{{lang}}

devenv-create-from lang class:  # Create a compound environment (e.g., just devenv-create-from python renpy).
  mkdir -p                      $HOME/.local/state/nix/profiles/dev/{{lang}}
  nix develop                   .#{{lang}}-{{class}}  --profile $HOME/.local/state/nix/profiles/dev/{{lang}}/kilig-{{lang}}-{{class}}

devenv-delete-all:              # Clear all environment configuration directories.
  rm -rf                        $HOME/.local/state/nix/profiles/dev/*

devenv-delete lang:             # Delete the specified locale directory
  rm -rf                        $HOME/.local/state/nix/profiles/dev/{{lang}}

devenv-delete-from lang class:  # Delete the profile for the composite environment (keeping the parent directory).
  rm -rf                        $HOME/.local/state/nix/profiles/dev/{{lang}}/kilig-{{lang}}-{{class}}*

devenv-update-all:              # Delete and then rebuild all environments (force refresh)
  @just dev-delete-all
  @just dev-create-all

devenv-show:                    # Display the output of all devShells in Flake.
  nix flake show | grep devShells -A21

devenv-list:                    # The created environment configurations are listed in a tree structure.
  eza --tree                    $HOME/.local/state/nix/profiles/dev

devenv-use lang:                # Enter an existing profile environment (without creating a persistent profile).
  nix develop                   .#{{lang}}  --profile $HOME/.local/state/nix/profiles/dev/{{lang}}/kilig-{{lang}}

devenv-use-from lang class:     # Enter an existing composite profile environment (without creating a persistent profile).
  nix develop                   .#{{lang}}-{{class}}  --profile $HOME/.local/state/nix/profiles/dev/{{lang}}/kilig-{{lang}}-{{class}}


