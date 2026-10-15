# @path: ~/projects/configs/nix-config/platform/nixos/system/dm/none/default.nix
# @author: redskaber
# @datetime: 2026-10-10
# @description: platform::nixos::dm::none — Null-Object display manager
# @directory: https://search.nixos.org/options
#
# The "no display manager" row: console hosts — the WSL form,
# headless servers — select display-manager = none. Deliberately
# empty, the same pattern as window-manager none (home/wm/none): the
# module's EXISTENCE is what keeps platform/nixos/system/dm/default.nix's
# router unconditional — no dm tag needs a call-site conditional.
#
# Nothing here sets services.displayManager.*: a host that routes
# here simply gets no DM (xserver stays off unless something else
# enables it — nothing in this tree does).

{ ... }:
{
  # Deliberately empty.
  imports = [ ];
}
