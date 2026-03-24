set shell := [ "bash", "-c" ]


devenv-create-all:
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

devenv-create lang:
  mkdir -p            $HOME/.local/state/nix/profiles/dev/{{lang}}
  nix develop         .#{{lang}}  --profile $home/.local/state/nix/profiles/dev/{{lang}}/kilig-{{lang}}

devenv-create-from lang class:
  mkdir -p            $HOME/.local/state/nix/profiles/dev/{{lang}}
  nix develop         .#{{lang}}-{{class}}  --profile $HOME/.local/state/nix/profiles/dev/{{lang}}/kilig-{{lang}}-{{class}}

devenv-delete-all:
  rm -rf              $HOME/.local/state/nix/profiles/dev/*

devenv-delete lang:
  rm -rf              $HOME/.local/state/nix/profiles/dev/{{lang}}

devenv-delete-from lang class:
  rm -rf              $HOME/.local/state/nix/profiles/dev/{{lang}}/kilig-{{lang}}-{{class}}*

devenv-update-all:
  @just dev-delete-all
  @just dev-create-all

devenv-show:
  nix flake show | grep devShells -A21

devenv-list:
  eza --tree          $HOME/.local/state/nix/profiles/dev

devenv-use lang:
  nix develop .#{{lang}}  --profile $HOME/.local/state/nix/profiles/dev/{{lang}}/kilig-{{lang}}

devenv-use-from lang class:
  nix develop .#{{lang}}-{{class}}  --profile $HOME/.local/state/nix/profiles/dev/{{lang}}/kilig-{{lang}}-{{class}}


