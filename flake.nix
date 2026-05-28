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
    in
    {
      packages.${system}.iso =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/profiles/minimal.nix"
            "${nixpkgs}/nixos/modules/profiles/installation-device.nix"
            ./limineISO.nix
          ];
        }).config.system.build.isoImage;
      checks.${system} = {
        isoBootTest = pkgs.testers.runNixOSTest {
          name = "limine iso boot test";
          nodes = {
            machine =
              { pkgs, modulesPath, ... }:
              {
                virtualisation = {
                  memorySize = 2048;
                  cores = 2;
                  qemu.options = [
                    "-cdrom" "${self.packages.${system}.iso}/nixos-limine.iso"
                    "-boot" "d"
                  ];
                };
              };
          };
          testScript = ''
            machine.start()
            machine.wait_for_unit("multi-user.target")
            machine.succeed("nixos-version")
            machine.shutdown()
          '';
        };
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
