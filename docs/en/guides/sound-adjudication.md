# The sound-Axis Adjudication Dossier — Debt #9, Semantic Half (T17.1)

> English mirror of [docs/guides/sound-adjudication.md](../../guides/sound-adjudication.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document is the adjudication dossier for README known debt #9, the
> "semantic half": the evidence inventory, the architectural facts, the
> adjudication matrices, and **the pre-adjudicated one-line flip** needed to
> flip the sound policy row on the console hosts. The mechanical half
> already landed in T10.1 (an independent policy axis + the `pipewire`/`none`
> enumeration + the `nixos_core_base_sound_gate` dual-law lock); this dossier
> advances the remaining, environment-gated part from "waiting for the real
> machine" to "decided the moment the machine arrives" — evidence collection
> has a dedicated verb (`just sound-audit`), the adjudication conclusions are
> pre-written (§4), and the flip lines are pre-staged as comments in the two
> hosts' shared.nix.

## 1. Adjudication scope

The sound axis is a NixOS system-layer policy (`platform/nixos/system/core/base/sound.nix`
reads the `shared.sound.value.sound-server` gate), so only hosts routed into
nixosConfigurations need to answer this axis:

| Host | Form | Adjudication status |
| --- | --- | --- |
| `nixos` | Bare-metal workstation (hyprland + ly desktop session) | **No adjudication needed** — the base policy `pipewire` is already the correct row (a desktop session consumes the local sound stack) |
| `vm` | QEMU guest, server-form console | **Pending adjudication** (§2, evidence A) |
| `nixos-wsl` | WSL2 distribution; this repo owns the system layer | **Pending adjudication** (§3, evidence B) |
| `wsl` | standalone HM (system layer not owned by this repo) | Out of scope — the sound module never enters its closure; the axis value is never consumed |
| `darwin` | nix-darwin platform tree | Out of scope — sound.nix is exclusive to platform/nixos |

## 2. Evidence A — `vm` (QEMU audio devices)

### Architectural facts

1. **A guest's audio devices are artifacts of the domain definition, not
   guaranteed to exist**: a bare `qemu-system-x86_64` without
   `-device`/`-audiodev` leaves the guest with no audio hardware at all,
   while libvirt/virt-manager domain templates usually attach
   `ich9-intel-hda` by default (the long-standing shape since Red Hat
   Bugzilla #1140937). That is: **the launcher's domain definition is the
   arbiter, and the launcher lives outside this repo** — precisely the
   reason this adjudication is environment-gated.
2. **This repo's declaration side has already answered half**: the
   `hardware` key of `hosts/vm/facter.json` (T5.12 declarative hardware
   facts) holds only `cpu` / `disk` / `storage_controller` /
   `network_controller` — **no audio devices**. The gap between declaration
   and probing is exactly what the real-machine audit must close (a
   virt-manager default domain attaches hda devices; probing would expose
   that immediately).
3. **With no ALSA cards, a local sound server has nothing to mediate**: the
   full pipewire stack (rtkit + the alsa layer + wireplumber + the mixer
   toolbelt) serves sound-card enumeration; an empty `/proc/asound/cards`
   proves the whole stack carries zero load.
4. The machine story (T7.2 adjudication) is a server-form maintenance
   machine: wm/dm both none, service-profile `server-pg-only`, app-set
   `none` — even if the launcher attaches audio devices, that story does
   not presuppose audio consumption.

### Probes (run inside the booted VM)

```bash
just sound-audit          # this dossier's mechanical evidence-collection verb (read-only; a wrapper around the probes below)
# or the manual equivalent:
lspci -nn | grep -iE 'audio|multimedia'   # PCI audio device presence
cat /proc/asound/cards                    # ALSA card enumeration (empty = no cards)
ls /dev/snd 2>/dev/null                   # device nodes
```

### Adjudication matrix

| Probe result | Adjudication | Rationale |
| --- | --- | --- |
| No PCI audio device + no ALSA cards | **`none`** | Declaration (facter) and probing agree; the local sound server has zero hardware to mediate |
| Audio device present (e.g. ich9-intel-hda) | **`none` (pre-adjudication unchanged)**, flipped to `pipewire` only if the owner explicitly wants sound through the display channel (SPICE/VNC) | The machine story (server-form) owns this adjudication; device presence ≠ intent to consume audio |

## 3. Evidence B — `nixos-wsl` (WSLg's Windows-side pulse bridge)

### Architectural facts (primary source: the microsoft/wslg README, "WSLg System Distro" section)

1. **Audio mediation runs in the system distro, not in the user distro**:
   "The system distro is a containerized Linux environment where the WSLg
   XServer, Wayland server and Pulse Audio server are running.
   Communication socket for each of these servers are projected into the
   user distro..." — the user distro (NixOS-WSL) consumes the projected
   sockets.
2. **`PULSE_SERVER` is preconfigured by WSLg**: "We preconfigure the user
   distro environment variables DISPLAY, WAYLAND_DISPLAY and PULSE_SERVER
   to refer these servers by default" — audio clients inside a WSLg
   session are routed to the Windows side, **whether or not a sound server
   also runs locally**.
3. **Audio data round-trips through the RDP channel**
   (`module-rdp-sink`/`module-rdp-source`); the user distro's kernel
   exposes no audio hardware to the guest — local pipewire inside WSL has
   no ALSA cards to serve and, inside a WSLg session, would never be
   selected by clients because `PULSE_SERVER` overrides it: **pure dead
   weight**.
4. WSLg can be turned off via `.wslconfig` — once off, not even the
   Windows-side server exists (the audio path vanishes wholesale), and the
   local stack still has nothing to do.
5. **SSH sessions do not inherit the WSLg environment**: in sessions where
   `PULSE_SERVER` is unset, clients fall back to the local default socket.
   For a maintenance console, "no audio in SSH sessions" is the correct
   semantics of the `none` row, not a defect (if audio in SSH sessions is
   wanted, that is a session-level configuration matter of pointing
   `PULSE_SERVER` at the wslg socket — not a reason to install a local
   server).

### Probes (run inside the WSL distro; must be run from a WSLg terminal session — SSH sessions do not inherit the WSLg env)

```bash
just sound-audit                        # mechanical evidence collection (read-only)
# or the manual equivalent:
test -S /mnt/wslg/PulseServer && echo socket-present
echo "PULSE_SERVER=${PULSE_SERVER:-<unset}"
```

(`pactl info` is optional: it needs the pulseaudio toolset, which the lean
console profile does not carry; the two probes — socket + env — already
suffice for adjudication.)

### Adjudication matrix

| Probe result | Adjudication | Rationale |
| --- | --- | --- |
| Socket present + `PULSE_SERVER` set | **`none`** | Audio mediation belongs to the host environment — the enumeration's own `none`-row contract comment (this answer was pre-written when T10.1 was drafted) |
| WSLg off / socket missing | **`none`** | The audio path does not exist at all; the local stack has nothing to do |

Both rows adjudicate the same — this host's evidence only affects the
attribution wording in the comment, not the conclusion.

## 4. Pre-adjudication and the one-line flip (pre-staged)

Both hosts' pre-adjudication is **`none`** (basis: the §2/§3 architectural
facts + each machine's story). With the three-layer policy chain
(fleet → role → host, R4) the flip's landing zone is **the console-family
row of the role table** — both vm (server) and nixos-wsl (console) take
their form from the console-form strategy bundle, so once the adjudication
is confirmed by real-machine evidence it is a one-line data change:

```nix
# lib/shared/lang/enum.nix · the console-form strategy bundle
sound = sound.none;   # the fleet default (pipewire) flipped by the role — one edit, both hosts
```

(The fleet base `shared.nix` keeps `sound = pipewire` as the fleet
default; wsl shares the console bundle — if its WSLg probe also hits a
matrix row it flips with the bundle, otherwise point wsl's registry row
at a custom role row carrying `sound = pipewire` — specialisation stays
one key away.)

The flip is data, not a file rewrite — a console host declares a different
row and the whole stack (pipewire + wireplumber + rtkit + ALSA persistence +
the pamixer/pavucontrol toolbelt) is subtracted wholesale (the none-form
wholesale-subtraction law of `nixos_core_base_sound_gate` has already locked
this path).

## 5. `just sound-audit` — mechanical evidence collection

`sound-audit` (hardware group, read-only) probes the hosting machine's form
by **runtime facts** — not the hostname, and not the policy declaration (the
verb layer's T4.0 law: read the resolved machine, not the declaration):

- `/proc/sys/kernel/osrelease` contains `microsoft` → WSL form (§3 probes)
- `systemd-detect-virt -v` (falling back to the `/proc/cpuinfo` hypervisor
  flag when absent) → virtual guest form (§2 probes)
- Anything else → bare-metal form: no pending adjudication items; the
  workstation default (`pipewire`) holds

The verb only collects and prints the matching matrix row and the suggested
flip — **it changes no files**.

## 6. Post-flip verification checklist

```bash
# value-plane probes (three toplevels — known boundary #10: drv hashes track the source tree; the value plane is the equivalence plane)
nix eval --raw .#nixosConfigurations.vm.config.services.pipewire.enable        # expected false
nix eval --raw .#nixosConfigurations.nixos-wsl.config.services.pipewire.enable # expected false
nix eval --raw .#nixosConfigurations.nixos.config.services.pipewire.enable     # expected true (unchanged)

# gate test (the dual laws for both forms are already locked in-tree; CI re-verifies automatically after the flip)
nix build .#api.checks.planes.nixos --no-link   # includes nixos_core_base_sound_gate
```

Once pushed, CI's deep-eval / host-toplevels / vm-tests legs re-verify
automatically per the face-sharded forms (T15.1); the `sound_gate` test
itself is orthogonal to the flip (both laws — the pipewire form and the none
form — are already in the assertions).

## 7. Sources

- The microsoft/wslg README (the three sections System Distro / WSLGd /
  Pulse Audio Plugin): the system distro hosts PulseAudio, socket
  projection, `PULSE_SERVER` preconfiguration, and RDP-channel audio
  round-tripping
- The Windows Command Line official blog, "WSLg Architecture" (2021-04):
  audio chosen as a PulseAudio server + sink/source plugins
- Red Hat Bugzilla #1140937 + community practice: libvirt/virt-manager
  domains default to the `ich9-intel-hda` audio device; the bare QEMU CLI
  attaches no audio device by default
- This repo: `hosts/vm/facter.json` (the no-audio-device declaration),
  `tests/nixos/core/base/sound-gate.nix` (the dual laws), and the sound
  row of `lib/shared/lang/enum.nix` (the none row's contract comment)
