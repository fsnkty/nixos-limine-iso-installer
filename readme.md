# nixos installer images using limine boot loader

# limine?
https://github.com/limine-bootloader/limine

# why?
started off just wanting to understand how nixos creates its installer images and wanting a smaller & easier to understand ISO creation.

Now I beleive limine would be a better fit than the current approach used in nixpkgs.
this module has a long ways to go before its on-par or better but gotta start somewhere.

# example use
creates a minimal profile installer ISO with the limine boot loader
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    limineISO = {
      url = "github:fsnkty/nixos-limine-iso-installer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system}.minimalISO =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            "${nixpkgs}/nixos/modules/profiles/installation-device.nix"
            inputs.limineISO.nixosModules.limineISO
            {
                limineISO.extraConfig = "timeout 5";
            }
          ];
        }).config.system.build.isoImage;
    };
}
```