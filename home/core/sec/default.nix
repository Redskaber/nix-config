# @path: ~/projects/configs/nix-config/home/core/sec/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::sec::default
#
# User-level security layer.
# Responsibility: user-facing security tooling and credential management.
#
# Boundary:
#   - This layer handles user-space security (SSH agent, GPG agent, credential helpers).
#   - System-level security (PAM, polkit, sops secret injection) lives in nixos/core/sec/.
#   - Application-level credential management (rbw) lives in home/core/exp/sys/base/rbw.nix.
#
# Currently empty — extension point for future user security modules:
#   - SSH agent configuration
#   - GPG agent (user-level, if not in srv/security)
#   - Keychain / secret-service integration


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    # Future: ./ssh-agent.nix
    # Future: ./gpg-agent.nix
  ];
}
