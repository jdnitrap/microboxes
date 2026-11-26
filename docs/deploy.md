# Deployment Guide

**microboxes uses traditional NixOS configuration (no flakes required).**

Host name is set to `microboxes`.

1. Clone the repo on a NixOS machine:
   ```bash
   git clone https://github.com/jdnitrap/microboxes.git
   cd microboxes
   ```

2. Copy your hardware config:
   ```bash
   sudo cp /etc/nixos/hardware-configuration.nix .
   ```

3. Build and switch:
   ```bash
   sudo nixos-rebuild switch -I nixos-config=$PWD/configuration.nix
   ```

4. After reboot, log in as `admin` / `changeme` (change password immediately).

5. Launch the manager:
   ```bash
   microboxes-manager
   ```

## Daily use
- Start/stop VMs from the GUI.
- Create labeled VMs → stubs land in `~/.microboxes/` → add to `configuration.nix` and rebuild.
