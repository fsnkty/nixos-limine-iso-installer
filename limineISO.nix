{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    isoImage = {
      isoName = lib.mkOption {
        type = lib.types.str;
        default = "nixos-limine.iso";
      };
      volumeId = lib.mkOption {
        type = lib.types.str;
        default = "NIXOS_LIMINE";
      };
    };
  };

  config = {
    system.stateVersion = "26.05";

    fileSystems = {
      "/" = {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };

      "/iso" = {
        device = "/dev/disk/by-label/${config.isoImage.volumeId}";
        fsType = "iso9660";
        options = [ "ro" ];
        neededForBoot = true; # Required for stage 1 mounting
      };
    };

    boot = {
      kernelParams = [
        "console=ttyS0"
        "panic=1"
        "boot.shell_on_fail"
      ];
      initrd = {
        systemd.enable = true;
        availableKernelModules = [
          "iso9660"
          "uas"
          "usb_storage"
          "sr_mod"
          "cdrom"
        ];
        kernelModules = [
          "squashfs"
          "overlay"
          "loop"
        ];
        systemd.storePaths = [
          pkgs.util-linux
          pkgs.coreutils
          pkgs.kmod
        ];
        systemd.services = {
          initrd-find-nixos-closure.after = [ "mount-squashfs-overlay.service" ];
          mount-squashfs-overlay = {
            description = "Mount Nix store squashfs overlay layer";
            wantedBy = [ "initrd-root-fs.target" ];
            after = [
              "sysroot.mount"
              "sysroot-iso.mount"
            ];
            before = [ "initrd-root-fs.target" ];

            unitConfig.DefaultDependencies = false;
            path = [
              pkgs.coreutils
              pkgs.util-linux
              pkgs.kmod
            ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              StandardOutput = "journal+console";
              StandardError = "journal+console";
            };

            script = ''
              export PATH="${pkgs.coreutils}/bin:${pkgs.util-linux}/bin:${pkgs.util-linux}/sbin:${pkgs.kmod}/bin:$PATH"

              set -x

              mkdir -p /sysroot/nix/.ro-store
              mkdir -p /sysroot/nix/.rw-store
              mkdir -p /sysroot/nix/store

              # 4. Proactively guarantee a loop device block node exists
              if [ ! -b /dev/loop0 ]; then
                mknod /dev/loop0 b 7 0
              fi

              echo "Mounting Nix store squashfs..."
              mount -t squashfs -o loop /sysroot/iso/nix/nix-store.squashfs /sysroot/nix/.ro-store

              mount -t tmpfs tmpfs /sysroot/nix/.rw-store
              mkdir -p /sysroot/nix/.rw-store/upper /sysroot/nix/.rw-store/work

              mount -t overlay overlay \
                -o lowerdir=/sysroot/nix/.ro-store,upperdir=/sysroot/nix/.rw-store/upper,workdir=/sysroot/nix/.rw-store/work \
                /sysroot/nix/store
            '';
          };
        };
      };
      loader = {
        grub.enable = false;
        systemd-boot.enable = false;
      };
    };

    system.build.isoImage =
      let
        closureInfo = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };
      in
      pkgs.stdenv.mkDerivation {
        name = config.isoImage.isoName;
        nativeBuildInputs = with pkgs; [
          squashfsTools
          libisoburn
          limine
          dosfstools
          mtools
        ];

        buildCommand = ''
          mkdir -p $out

          echo "=> Creating SquashFS..."
          mksquashfs $(cat ${closureInfo}/store-paths) nix-store.squashfs -noappend -comp xz

          echo "=> Preparing UEFI ESP (64MB FAT32)..."
          truncate -s 64M efi.img
          mkfs.vfat -F 32 -n "LIMINE_EFI" efi.img
          mmd -i efi.img ::/EFI ::/EFI/BOOT
          mcopy -i efi.img ${pkgs.limine-full}/share/limine/BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI
          mcopy -i efi.img ${pkgs.limine-full}/share/limine/BOOTIA32.EFI ::/EFI/BOOT/BOOTIA32.EFI

          echo "=> Organizing ISO root..."
          mkdir -p iso_root/boot/limine iso_root/nix
          cp nix-store.squashfs iso_root/nix/nix-store.squashfs
          cp ${config.system.build.kernel}/${config.system.boot.loader.kernelFile} iso_root/boot/vmlinuz
          cp ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} iso_root/boot/initrd
          cp ${pkgs.limine-full}/share/limine/limine-bios.sys iso_root/boot/limine/
          cp ${pkgs.limine-full}/share/limine/limine-bios-cd.bin iso_root/boot/limine/
          cp efi.img iso_root/boot/limine/efi.img

          cat << EOF > iso_root/boot/limine/limine.conf
          timeout: 5

          /NixOS (Limine Systemd Initrd)
              protocol: linux
              path: boot():/boot/vmlinuz
              module_path: boot():/boot/initrd
              cmdline: init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
          EOF

          echo "=> Building ISO..."
          xorriso -as mkisofs \
            -b boot/limine/limine-bios-cd.bin \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            --eltorito-alt-boot \
            -e boot/limine/efi.img \
            -no-emul-boot \
            -volid "${config.isoImage.volumeId}" \
            -o $out/${config.isoImage.isoName} \
            iso_root

          echo "=> Installing Limine MBR..."
          limine bios-install $out/${config.isoImage.isoName}
        '';
      };
  };
}
