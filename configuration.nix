# microboxes - Traditional NixOS configuration (no flakes)
# Usage: sudo nixos-rebuild switch -I nixos-config=/path/to/microboxes/configuration.nix

{ config, pkgs, lib, ... }:

let
  # Import hardware configuration from the same directory
  hardwareConfig = ./hardware-configuration.nix;
in

let
  # Manager GUI package with Python + tkinter
  python-with-tk = pkgs.python3.withPackages (p: with p; [ tkinter ]);

  microboxes-manager = pkgs.stdenv.mkDerivation {
    name = "microboxes-manager";
    src = ./scripts;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      mkdir -p $out/bin $out/share/applications
      cp gui-launcher.py $out/bin/microboxes-manager-unwrapped
      chmod +x $out/bin/microboxes-manager-unwrapped

      # Wrap with Python + tkinter
      makeWrapper ${python-with-tk}/bin/python3 $out/bin/microboxes-manager \
        --add-flags $out/bin/microboxes-manager-unwrapped

      cat > $out/share/applications/microboxes-manager.desktop << EOF
      [Desktop Entry]
      Name=microboxes VM Manager
      Comment=Start, stop, and create microVMs
      Exec=microboxes-manager
      Icon=utilities-system-monitor
      Terminal=false
      Type=Application
      Categories=System;Virtualization;
      EOF
    '';
  };
in
{
  imports = [
    hardwareConfig
    # Import microvm.nix if available (via channels or git submodule)
    # ./microvm-nix/nixosModules/host
  ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Host configuration
  networking.hostName = "microboxes";
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix features
  nix.settings.experimental-features = [
    "nix-command"
  ];
  nixpkgs.config.allowUnfree = false;

  # Users
  users.mutableUsers = true;
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "kvm" ];
    initialPassword = "changeme";
  };

  # Desktop: labwc on Wayland
  programs.labwc.enable = true;
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.labwc}/bin/labwc";
      user = "admin";
    };
  };

  environment.etc."xdg/labwc/autostart".text = ''
    ${pkgs.foot}/bin/foot &
  '';

  environment.etc."xdg/labwc/rc.xml".text = ''
    <?xml version="1.0"?>
    <labwc_config>
      <keyboard>
        <keybind key="W-Return">
          <action name="Execute" command="${pkgs.foot}/bin/foot"/>
        </keybind>
      </keyboard>
    </labwc_config>
  '';

  # Networking (minimal: systemd-networkd)
  networking.networkmanager.enable = false;
  networking.useNetworkd = true;

  systemd.network = {
    enable = true;
    networks."10-eth" = {
      matchConfig.Type = "ether";
      DHCP = "yes";
      dhcpConfig = {
        UseDNS = true;
        UseNTP = true;
      };
    };
  };

  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [ "1.1.1.1" "8.8.8.8" ];
  };

  # SSH (optional)
  services.openssh.enable = true;

  # Essential packages
  environment.systemPackages = with pkgs; [
    salt
    git
    vim
    python3
    tk
    microboxes-manager
    qemu
    iproute2
    bridge-utils
    foot
    curl
  ];

  # Microvm host support (requires microvm.nix)
  # Uncomment and configure after adding microvm.nix to your system
  # microvm.vms = { ... };

  system.stateVersion = "26.05";
}
