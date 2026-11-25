{ microvm, pkgs, ... }:
let
  minimal = { lib, pkgs, ... }: {
    imports = [ microvm.nixosModules.microvm ];
    users.users.root.password = "";
    system.stateVersion = "26.05";
    microvm = {
      hypervisor = "cloud-hypervisor";
      mem = 512;
      vcpu = 1;
      shares = [{
        proto = "9p";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }];
      writableStoreOverlay = "/nix/.rw-store";
      volumes = [{
        image = "overlay.img";
        mountPoint = "/nix/.rw-store";
        size = 1024;
      }];
      socket = "control.socket";
    };
    environment.systemPackages = with pkgs; [ vim ];
  };

in
{
  templates = {
    inherit minimal;
  };
}
