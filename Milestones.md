# Milestones

Exact picture of the build, in order. Each milestone: **where you should be**, **what must exist**, **done when**, **not yet**. Do not skip ahead to seamless windows or vfio before VMs boot.

Pair with [[Nixos Qubes Setup]] and [[Flow Plan]].

Target: a **new NixOS machine**, not an existing desktop.

---

## Map (read this first)

| # | Name | You can… | Seamless? |
|---|---|---|---|
| 0 | Decisions | Know the stack | No |
| 1 | Bare NixOS + labwc | Sit at a thin Wayland host | No |
| 2 | First microVM | SSH or serial into a guest | No |
| 3 | TAP + NAT | Guest reaches the internet via host NAT | No |
| 4 | App-list guests | Declare packages per VM | No |
| 5 | Persistent + disposable | `work` keeps `/home`; `disp` dies | No |
| 6 | `fw` + `net` | Host has no uplink; policy VM exists | No |
| 7 | VM manager + SPICE | Click start; VM is a **window on labwc** | **Windows, not seamless** |
| 8 | Daily use | Work in SPICE windows for real | No |
| 9 | virtio-Wayland | Guest **app** is a labwc window | **Yes, experimental** |
| 10 | Color + policy | Borders, vsock allowlist, copy-to-VM | Yes |
| 11 | `usb` + `vault` + vfio NIC | Qubes-like devices | Yes |
| 12 | Harden / polish | Docs, backups, less host | Yes |

**Projection:** 1–7 is the real product you can live on. 8 is proving it. 9–12 is the Qubes-like UI and devices. 9 can fail or slip; 7 must not.

---

## Milestone 0 — Decisions (now)

**Where you should be:** Paper only. No install required.

**Locked:**

- KVM + microvm.nix, not Xen
- Host: NixOS stripped, **labwc / Wayland**, autologin
- Guests: `base.nix` + package lists
- Nix defines VMs; Salt in `salt/` starts them
- Seamless = virtio-Wayland later; SPICE first
- XFCE only inside guests if needed
- cloud-hypervisor for apps; QEMU for vfio

**Done when:** These notes match what you still want. (They do, as of this file.)

---

## Milestone 1 — Thin host boots

**Where you should be:** Dedicated disk/partition on the **target PC**. Fresh NixOS.

**Must exist:**

- `hardware-configuration.nix` **generated on that machine**
- Flake with `nixosConfigurations.<hostname>`
- `documentation.enable = false` (or equivalent)
- No GNOME/KDE/GDM
- **labwc** session, autologin, mouse, one terminal
- Optional tiny panel (waybar) — can wait
- User with sudo; SSH optional
- KVM enabled (`boot.kernelModules` / `virtualisation.libvirtd` not required; KVM device nodes enough)
- You can open a terminal with the mouse

**Not yet:** microVMs, TAP, browser on host.

**Done when:** Reboot → labwc → terminal. No extra DE. Store is small compared to a workstation.

**If stuck:** GPU/Wayland on that hardware. Fix labwc/Mesa before any VM.

---

## Milestone 2 — One throwaway microVM

**Where you should be:** Host still has internet (NetworkManager or dhcpcd on the host is OK **temporarily** so you can rebuild).

**Must exist:**

- `microvm.nixosModules.host` imported
- One guest: `hello` or `disp-test`
- virtiofs share of `/nix/store`
- Guest: `base.nix` only (login, sshd or serial)
- `microvm.hypervisor = "cloud-hypervisor"` (or qemu if CH is painful)
- Start: `systemctl start microvm@hello` (or equivalent)
- You can log into the guest (SSH from host to guest IP, or serial)

**Not yet:** TAP to the LAN, GUI in the guest, no host-uplink policy.

**Done when:** `systemctl status microvm@hello` is running; you get a shell in the guest; reboot host, guest can start again.

**If stuck:** virtiofsd permissions, CH vs qemu, vsock-ssh. Fall back to qemu user-net for this milestone only.

---

## Milestone 3 — Guest networking (host NAT)

**Where you should be:** Still a learning net. Host **may** still own the NIC.

**Must exist:**

- TAP `vm-*` created by microvm host module
- Host bridge or NAT (`networking.nat` / firewall masquerade)
- Guest has an IP and default route via host
- From guest: `ping 1.1.1.1` and DNS work
- Document the TAP names and IPs

**Not yet:** `fw` VM, host without default route, vfio.

**Done when:** Guest curl/ping works. Host still a normal NixOS box with a NIC.

This is **deliberately leaky**. You need internet in the guest to test. Isolation comes in 6.

---

## Milestone 4 — Base + app lists

**Where you should be:** Declaring VMs as lists, not cloning disks.

**Must exist:**

```
modules/base.nix
modules/presets/graphical.nix   # optional compositor or single-app Wayland/X in guest
modules/presets/networked.nix
modules/vms/browser.nix         # packages = [ firefox ];
modules/vms/dev.nix             # editor + git
```

- Two guests with **different package lists**
- Same `base.nix`
- Rebuild host → guest closure changes → reboot guest → new apps
**Not yet:** Pretty GUI, disposables required.

**Done when:** You add a package to one VM’s list, rebuild, reboot that VM, the package is there; the other VM does not gain it.

---

## Milestone 5 — Persistent `work` + disposable `disp`

**Where you should be:** Qubes AppVM vs DisposableVM, Nix-style.

**Must exist:**

- `work`: extra disk or virtiofs for `/home` that **survives** reboot
- `disp`: overlay only; kill VM → data gone
- Start `disp`, create a file, stop VM, start again → file missing
- Start `work`, create a file, reboot → file present

**Done when:** Those two tests pass every time.

---

## Milestone 6 — `fw` + `net`; host drops uplink

**Where you should be:** Real isolation. This is the first **security** milestone.

**Must exist:**

- Bridge `vmfw` with **no** default route on the host
- `fw` VM: nftables, forwarding
- `net` VM: owns the path to the physical NIC (still via host bridge/NAT is OK; vfio is milestone 11)
- AppVMs only attached to `vmfw`
- Host cannot browse the internet (no default route). Rebuilds: use a temporary exception, USB stick, or a “host-update” hole you document
- `vault` definition exists with **zero** TAP (can wait to boot it)

**Policy (minimum nftables):**

- `work`, `personal`, `disp` → may reach `fw` then `net`
- `disp` may not talk to `work` directly
- host may talk to guests only for SSH/admin on a **mgmt** network you define, or only vsock later

**Done when:** From host, `ping 8.8.8.8` fails (or only works through a documented exception). From `work` guest, internet works. From `disp`, internet works. Guests cannot SSH to each other unless allowed.

**If stuck:** Keep host NAT (milestone 3) and **document** “isolation postponed.” Do not pretend 6 is done.

---

## Milestone 7 — Manager GUI + SPICE on labwc

**Where you should be:** **This is the first “desktop.”** Qubes-like *workflow*, not seamless apps.

**Must exist:**

- VM manager on labwc: list VMs, start, stop, status
- Starting `work` opens **virt-viewer / SPICE** as a **labwc window**
- Mouse works in that window
- Inside the guest: either one app (Firefox) or a small guest session (labwc/XFCE **in the VM**)
- Window title or label shows VM name (`work`, `disp`)
- Optional: labwc rule for a colored border on the **viewer** window (fake Qubes color)

**Not yet:** Firefox as a native labwc window without SPICE.

**Done when:** Autologin → labwc → click Work → a window → you can browse. Click Disp → another window. No host browser.

**This is the picture you should expect to live with for a while.** It is not Qubes seamless. It is compartmentalized and usable.

---

## Milestone 8 — Daily-driver check

**Where you should be:** Using **only** this machine for a week of real tasks in SPICE windows.

**Must exist:**

- `work` and `personal` (or `dev` + `browser`) as you actually work
- Rebuild/update procedure written down (how the host gets packages with no uplink)
- Backup of `/home` disks
- You know how to get a host terminal if labwc dies

**Done when:** You are not bouncing back to another OS to “just quickly” browse. Pain is listed (audio, clipboard, file copy). That list feeds 10–11.

**If you cannot live here:** stay on 7 and fix guest apps/audio/clipboard-inside-the-VM. Do not jump to 9 to escape pain.

---

## Milestone 9 — Seamless: guest app → labwc window

**Where you should be:** The **aim**. Experimental.

**Must exist:**

- cloud-hypervisor (or qemu) with virtio-gpu / Wayland proxy path
- `wayland-proxy-virtwl` or microvm.nix graphics
- One guest app (e.g. Firefox or a terminal) appears as a **normal labwc window**
- You can move/resize it like a local app
- SPICE still available as fallback

**Done when:** One app from `work` is a labwc window without a SPICE frame. Screenshot-able.

**Failure is allowed.** If this never stabilizes, **milestone 7 remains the product**. Seamless is an upgrade, not the definition of success.

**Needs down the road:** Spectrum/CH patches, GPU on the host, guest Mesa, seatd, maybe PipeWire for audio. Plan time for breakage.

---

## Milestone 10 — Color, policy, copy

**Where you should be:** Qubes *habits*.

**Must exist:**

- labwc rules: `work` windows one border color, `disp` another (SPICE titles and/or Wayland app_id)
- vsock (or SSH) **allowlist** on the host:
  - example: `disp` may pass a URL to `work`
  - deny everything else
- Explicit **copy file to VM** (script or manager button). No shared `~/`
- Clipboard: **off** by default; “Send clipboard to work” action later

**Done when:** You cannot drag a file from host to guest by accident. Colors are obvious. One allowed RPC works; a denied one fails.

---

## Milestone 11 — Devices: usb, vault, vfio NIC

**Where you should be:** Qubes sys-usb / vault / sys-net.

**Must exist:**

- `vault`: no TAP, persistent encrypted `/home`, manager can start it
- `usb`: QEMU + USB controller vfio **or** USB redirect to one guest at a time
- `net`: physical NIC vfio into `net` VM; host has no NIC in Linux (or it’s unbound)
- IOMMU on in firmware; documented for **that** motherboard

**Done when:** Unplug/plug USB shows up in `usb` (or attached guest), not in host. `vault` has no ping. Internet still works through `net`.

**Hardware-dependent.** Some PCs will not vfio Wi-Fi. Then `net` stays on a host TAP/NAT and you **record that limit**.

---

## Milestone 12 — Harden and document

**Where you should be:** Someone else (or future you) can install from the flake.

**Must exist:**

- README: install on new hardware, generate hardware config, first boot
- Host package list audited (still no browser)
- Backup: flake + `/home` volumes
- Optional: measured boot / Secure Boot — **later**, not required
- Sketch merged from `flakemicro2` into this directory. The GitHub repo was left in place.

**Done when:** Clean install on the target (or a spare) reaches milestone 7 from the flake.

---

## What you need down the road (shopping list)

**Always (1–8)**

- Target PC with KVM (almost any 64-bit)
- Disk for NixOS
- Ethernet or Wi-Fi (vfio later)
- microvm.nix, cloud-hypervisor or qemu
- labwc, seatd, a terminal, virt-viewer
- Time: host + first VM is days; isolation + GUI is weeks of evenings

**For 9 (seamless)**

- Working host GPU on Wayland
- virtio-gpu / wayland-proxy-virtwl
- Likely Cloud Hypervisor graphics patches (Spectrum)
- Patience; this is the research item

**For 11 (vfio)**

- IOMMU (Intel VT-d / AMD-Vi) on in BIOS
- Chipset that can isolate the NIC/USB controller
- Willingness to lose host NIC if it goes into `net`

**Never required**

- Xen
- GNOME on the host
- IceWM
- Qubes GUI protocol
- Per-app VM for *every* binary on day one (lists of 1–3 apps are enough)

---

## Structure to lay out in the flake (when coding starts)

Do **not** implement until you ask. This is the map:

1. `flake.nix` — host + maybe guest configs as `nixosConfigurations` / `microvm.vms`
2. `modules/host.nix` — KVM, labwc, autologin, bridges, virtiofsd, manager package
3. `modules/base.nix` — every guest
4. `modules/presets/{graphical,networked}.nix`
5. `modules/vms/{net,fw,work,personal,disp,vault}.nix` — **package lists here**
6. `pkgs/vm-manager/` — small GUI (GTK/Qt/Python like flakemicro2 launcher)
7. `docs/network.md` — TAP names, IPs, nftables
8. Hardware file **only** from the install machine

Order of **code** matches milestones: host (1) → one VM (2) → net (3) → lists (4) → disks (5) → fw/net (6) → manager+SPICE (7) → then 9+.

---

## Success picture (honest)

**Minimum success:** Milestone 7–8. Thin labwc host, click to open VMs as windows, different apps per VM, `disp` wipes, host has no browser. Looks like “Qubes with SPICE frames.”

**Full aim:** Milestone 9–10. Same host, Firefox from `work` is a labwc window with a colored border. Looks closer to Qubes/Spectrum.

**Not promised:** Xen isolation, Qubes polish, vfio on every laptop, seamless on day one.

If 9 never works, you still have a real compartmentalized NixOS workstation at 7–8.
