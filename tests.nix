{
  pkgs,
  lib,
  nixpkgs,
  iso,
}:
let
  qemu-common = pkgs.callPackage (nixpkgs + "/nixos/lib/qemu-common.nix") { };
  qemu = qemu-common.qemuBinary pkgs.qemu_test;

  mkStartCommand =
    {
      usb,
      uefi ? false,
      extraFlags ? [ ],
    }:
    let
      flags = [
        "-m"
        "2048"
        "-netdev"
        "user,id=net0"
        "-device"
        "virtio-net-pci,netdev=net0"
      ]
      ++ lib.optionals (usb != null) [
        "-device"
        "usb-ehci"
        "-drive"
        "id=usbdisk,file=${usb},if=none,readonly"
        "-device"
        "usb-storage,drive=usbdisk"
      ]
      ++ lib.optionals uefi [
        "-drive"
        "if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}"
        "-drive"
        "if=pflash,format=raw,unit=1,readonly=on,file=${pkgs.OVMF.variables}"
      ]
      ++ extraFlags;
    in
    "${qemu} ${lib.concatStringsSep " " flags}";

  makeBootTest =
    name: config:
    pkgs.testers.runNixOSTest {
      name = "boot-${name}";
      nodes = { };
      testScript = ''
        machine = create_machine("${mkStartCommand config}")
        machine.start()
        machine.succeed("nixos-version")
        machine.shutdown()
      '';
    };

in
{
  uefi-usb = makeBootTest "uefi-usb" {
    uefi = true;
    usb = "${iso}/nixos-limine.iso";
  };
  bios-usb = makeBootTest "bios-usb" { usb = "${iso}/nixos-limine.iso"; };
}
