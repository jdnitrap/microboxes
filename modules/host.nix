{ pkgs, templates, ... }:
let
  nixqubes-manager = pkgs.stdenv.mkDerivation {
    name = "nixqubes-manager";
    src = ../scripts;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      mkdir -p $out/bin $out/share/applications
      cp gui-launcher.py $out/bin/nixqubes-manager
      chmod +x $out/bin/nixqubes-manager
      # Ensure shebang works
      sed -i '1s|.*|#!${pkgs.python3}/bin/python3|' $out/bin/nixqubes-manager
      cat > $out/share/applications/nixqubes-manager.desktop << EOF
      [Desktop Entry]
      Name=nixqubes VM Manager
      Comment=Start, stop, and create microVMs
      Exec=nixqubes-manager
      Icon=utilities-system-monitor
      Terminal=false
      Type=Application
      Categories=System;Virtualization;
      EOF
    '';
  };
in
{
  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking (minimal: no default route on host)
  networking.hostName = "nixqubes";
  # Network config is manual via iproute2; see docs/networking.md
  networking.networkmanager.enable = false;
  networking.useNetworkd = true;

  # Locale / time
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix experimental features
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = false;

  # Users
  users.mutableUsers = true;
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "kvm" ];
    initialPassword = "changeme";
  };
  # Desktop: labwc on Wayland. No XFCE, LightDM, GDM, or SDDM.
  # greetd starts labwc for admin with no greeter.
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
  # SSH (optional, for remote management)
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    # Core management
    salt
    git
    vim

    # GUI manager (includes .desktop file)
    python3
    tk
    nixqubes-manager

    # MicroVM / hypervisor support
    qemu
    iproute2
    bridge-utils

    # Host terminal on labwc. Super+Return opens another.
    foot

    # Minimal utilities
    curl
  ];

  # Day-to-day VMs
  # Networking note: switch type = "user" to type = "tap" + host bridge
  # once sys-net owns the real NIC (see docs/networking.md).
  microvm.vms = {
    sys-net = {
      autostart = false;
      config = {
        imports = [ templates.minimal ];
        networking.hostName = "sys-net";
        microvm.interfaces = [{
          type = "user"; # change to tap after host bridge setup
          id = "net";
          mac = "02:00:00:00:00:10";
        }];
      };
    };
    personal = {
      autostart = false;
      config = {
        imports = [ templates.minimal ];
        networking.hostName = "personal";
        microvm.interfaces = [{
          type = "user";
          id = "personal";
          mac = "02:00:00:00:00:11";
        }];
        environment.systemPackages = with pkgs; [ firefox libreoffice ];
      };
    };
    work = {
      autostart = false;
      config = {
        imports = [ templates.minimal ];
        networking.hostName = "work";
        microvm.interfaces = [{
          type = "user";
          id = "work";
          mac = "02:00:00:00:00:12";
        }];
        environment.systemPackages = with pkgs; [ git vim ];
      };
    };
  };

  system.stateVersion = "26.05";
}
