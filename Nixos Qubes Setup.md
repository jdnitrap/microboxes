# NixOS like Qubes (KVM + microVMs)

Decisions for a **dedicated NixOS machine** used as a Type-1-style **KVM hypervisor**. Not this (or any other) existing desktop. Generate `hardware-configuration.nix` on the box you install.

Companion notes:

- [[Flow Plan]] — how the pieces connect
- [[Milestones]] — staged goals, what exists at each stage, what comes later

---

## Aim

Qubes-shaped **seamless UI**: one host desktop, apps (or whole guest sessions) as **windows**, trust by VM. Stack is **NixOS + KVM + microvm.nix**, not Xen.

Qubes uses Xen + XFCE in Dom0 + a custom X11 GUI. This project copies the **shape** (thin host, templates-as-base, AppVMs, sys-net, disposables) and uses **Wayland + labwc** so guest windows can later sit on the host without rewriting Qubes’ GUI daemon.

---

## Locked decisions

| Topic | Decision |
|---|---|
| Hypervisor | **KVM** (Linux kernel). NixOS is Dom0. |
| VM tooling | **[microvm.nix](https://github.com/microvm-nix/microvm.nix)** only |
| Xen | Packaged in nixpkgs; **out of scope**. Would be a different install. |
| Host OS | NixOS, **stripped**. No browser, mail, IDE, Flatpak on the host. |
| Host UI | **Wayland + labwc**. Autologin. No GDM/SDDM. IceWM/X11 skipped (dead end for virtio-Wayland). |
| Seamless UI | **labwc + virtio-Wayland / wayland-proxy-virtwl** (Spectrum path). Experimental. |
| Groundwork windows | SPICE / virt-viewer: each VM is a window **on labwc**. Not seamless yet; required first. |
| XFCE | Optional **inside AppVMs**, never the host compositor. |
| Guests | Thin **NixOS base** + **package list per VM**. No fat workstation template. |
| Template | `minimal` is the template. Shared read-only `/nix/store` is the root. Overlay and optional `/home` are the private disk. |
| Config manager | **Nix** defines the VMs. **Salt** starts them and may check them. Salt is not the policy. |
| App VMM | **cloud-hypervisor**, launched by microvm.nix |
| Passthrough VMM | **QEMU** only (`net`, `usb` vfio). No third VMM for the GPU. |
| Salt | Kept, on the host. See below. |

---

## Qubes → this project

| Qubes | Here |
|---|---|
| Xen Dom0 | Thin NixOS host: labwc, `microvm.nix` host module, virtiofsd |
| TemplateVM | `minimal`: shared `/nix/store`, not a cloned disk image |
| AppVM | microVM + optional persistent `/home` + `packages = [ ... ]` |
| DisposableVM | overlay only, wiped on stop |
| sys-net | `net` microVM, physical NIC (vfio later) |
| sys-firewall | `fw` microVM, nftables |
| sys-usb | `usb` microVM (later) |
| vault | microVM, **no** TAP |
| qrexec | vsock + allowlist (later) |
| Colored windows | labwc window rules / later proxy |

Host kernel is still the TCB. A kernel bug can see guests. Isolation is still stronger than one fat desktop + Flatpak.

The template still makes the AppVM. Qubes uses a disk snapshot because a Fedora template is one installed system. Here the template is `minimal` plus that VM's package list. `personal` can have Firefox without putting Firefox on `work`. A disposable is `minimal` with no `/home` disk.

---

## Salt

Salt stays. It runs on the host. It does not create the isolation.

- It may start and stop the set, in order: `net`, then `fw`, then app VMs. `vault` is never given a network unit.
- It may check: fail if `vault` has an uplink, or if the host has a default route.
- It may configure a future guest that Nix cannot build, such as Windows.
- It does not install guest packages, open the firewall, or hold the copy/clipboard allow-list. Those live in the flake and in a policy file. Salt may apply that file. It is not the file.

The states in `salt/` today only run `systemctl start` for `sys-net`, `personal`, and `work`.

---

## Taken from Qubes and Spectrum

From Qubes, still to build: `net`, `fw`, and later `usb` as service VMs with real jobs; disposables; a policy file for copy, clipboard, and open-a-link; a colored border per label.

From Spectrum: per-VM memory and CPU caps; the VMM cannot write the directory that names the VM; files enter a VM by a grant, not a shared folder; seamless mode is one Wayland surface on labwc, with SPICE as the fallback.

Left out, because this project already chose another way:

- Xen, and the Qubes X11 GUI agent. The host compositor is labwc. The later window path is virtio-Wayland.
- Spectrum's musl host, s6-rc, and reinstall-to-update. Updates stay `nixos-rebuild`.
- A second virtual machine monitor whose only job is the GPU. Cloud Hypervisor for app VMs, QEMU for VFIO.
- Qubes template disks. The shared store is the read-only template.

---

## Where the tree is

This directory is a sketch. It has not been built or installed. It is not a git repo. The public repo [jdnitrap/flakemicro2](https://github.com/jdnitrap/flakemicro2) is unchanged. Deleting it was skipped.

The sketch has a labwc host, greetd autologin, `minimal` on Cloud Hypervisor, `sys-net`, `personal`, and `work`, Salt, and a VM manager. It does not have the bridge, `fw`, SPICE, disposables, per-VM `/home`, or cgroups. The host still has NetworkManager, SSH, and `admin` / `changeme`.

Removed while merging the old sketch: the other PC's hardware file, the workstation template, XFCE on the host, a host browser, and passwordless sudo. Generate hardware config on the machine you install.

The notes describe the security model. This tree does not implement it yet. Do not treat a boot of the sketch as the secure system.

---

## Network model

```
AppVMs / disp / vault
        │ TAP
        ▼
  host bridge vmfw   (no uplink)
        │
        ▼
     fw microVM      nftables policy
        │
        ▼
     net microVM     DHCP, physical NIC
        │
        ▼
   hardware NIC
```

- Host has **no** default route through the NIC. Host only talks to VM bridges.
- `vault` has no TAP.
- File copy host↔VM is explicit (later vsock), not a shared home.

---

## Guest shape

Every guest:

- Read-only NixOS from host store (virtiofs)
- Writable overlay for `/`
- Optional `/home` disk
- Small RAM/CPU
- `cloud-hypervisor` unless vfio → QEMU

A VM is **base + optional presets + package list**, e.g. `base + graphical + networked + [ firefox ]` vs `base + [ keepassxc ]` with no net.

---

## What you must write (not in microvm.nix)

- VM manager GUI (start/stop, labels)
- nftables policy on `fw`
- vsock allowlist (qrexec-like)
- Clipboard “send to VM X”
- USB attach
- labwc rules for colored borders
- virtio-Wayland wiring (Spectrum / microvm graphics)

Updates: `nixos-rebuild` on the host, reboot guests. Better than Qubes template disks.

---

## Honest limits

Seamless windows are **experimental**. SPICE always works. This will not be Xen/Qubes. It can be a usable KVM compartmentalized NixOS desktop if milestones are done in order.

See [[Milestones]] for the staged picture. See [[Flow Plan]] for structure.
