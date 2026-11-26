{
  description = "Qubes-inspired NixOS MicroVMs with microvm.nix";

  nixConfig = {
    extra-substituters = [ "https://microvm.cachix.org" ];
    extra-trusted-public-keys = [ "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, microvm }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      templatesMod = import ./modules/templates.nix { inherit microvm pkgs; };
      templates = templatesMod.templates;
    in {
      nixosConfigurations = {
        microboxes = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            microvm.nixosModules.host
            ./hardware-configuration.nix
            (import ./modules/host.nix { inherit pkgs templates; })
          ];
        };
      };
    };
}
