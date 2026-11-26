# microboxes

This is a working project. It is not machine-ready. Do not install it on a computer you rely on. The notes describe the system we are aiming at. The flake is a sketch of that system, and it has not been built or installed.

Copying and modification are allowed for non-commercial use under the [license](LICENSE). If you distribute a modified version, you must license it on these same terms and offer the changes back to this repository. Commercial use is not allowed.

The minimum host is labwc, Nix, KVM, and `virtiofsd`. One generation of that host is about 4–6 GB. Plan on a 20 GB disk, or 40 GB if you keep old generations and a few guests. Networking uses systemd-networkd (DHCP) for minimal setup. Details are in `Nixos Qubes Setup.md`.

## Scope

Replicate the **Qubes OS architectural model** on NixOS using [microvm.nix](https://github.com/microvm-nix/microvm.nix).

This means the same shape and workflow:

- Trusted host (Dom0-like) that mainly manages VMs
- Templates that other VMs inherit from
- Purpose-specific AppVMs (personal, work, etc.)
- Disposable / temporary VMs
- Dedicated network VM (sys-net) that owns networking
- GUI-driven management from the host
- Declarative control: Nix defines the VMs, Salt on the host starts them

The security model is the Qubes shape on KVM: thin host, one template (`minimal`), AppVMs, `net` and `fw`, disposables. The files in this directory are a sketch of that model. They are not the model yet. See `Nixos Qubes Setup.md`.

## What you get
- labwc host named `microboxes` with admin user (`admin` / `changeme`, mutable users). greetd autologin, no XFCE.
- One guest template: `minimal` (Cloud Hypervisor, shared `/nix/store`)
- Purpose VMs: `sys-net`, `personal`, `work`, each a package list on `minimal`
- GUI manager for start/stop/status, temporary sessions, and labeled VM creation
- Salt states in `salt/` to start `sys-net`, `personal`, and `work`
- Deploy and networking guides

## Structure
- `flake.nix` — thin entry point
- `modules/host.nix` — host configuration
- `modules/templates.nix` — `minimal` guest
- `scripts/gui-launcher.py` — day-to-day manager
- `docs/deploy.md`, `docs/networking.md`, `docs/harden.md`
- `hardware-configuration.nix` is not in the tree. Generate it on the target machine and add it to `flake.nix`.

## Deploy

```bash
sudo nixos-rebuild switch --flake .#microboxes
```

After switch, log in as `admin` / `changeme` and run the manager.

## Daily use
- GUI: start/stop purpose VMs, launch temporary sessions, create labeled VMs.
- Labeled VM stubs land in `~/.microboxes/` — paste into the flake and rebuild.
- Networking isolation steps: `docs/networking.md`.
- TCB minimization / hardening: `docs/harden.md`.

Handbook: https://microvm-nix.github.io/microvm.nix/
