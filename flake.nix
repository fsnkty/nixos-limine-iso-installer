{
  description = "NixOS Minimal Installer ISO with Limine Bootloader";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;
    in
    {
      packages.${system}.minimalISO =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            "${nixpkgs}/nixos/modules/profiles/installation-device.nix"
            ./limineISO.nix
          ];
        }).config.system.build.isoImage;
      checks.${system} = import ./tests.nix {
        inherit pkgs lib nixpkgs;
        iso = self.packages.${system}.minimalISO;
      };
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.nixpkgs-fmt
          pkgs.deadnix
          pkgs.statix
        ];
      };
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
