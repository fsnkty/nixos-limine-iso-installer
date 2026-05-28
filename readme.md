# nixos installer images using limine boot loader

# what is limine?
https://github.com/limine-bootloader/limine

# why?
I just wanted a smaller ISO installer.
limine seems best for clean bios and uefi support.

I dont have a use for bios booting, so users able to test that would be appreciated.

# test
nix build .#checks.x86_64-linux.isoBootTest -L --rebuild

# contributions
bios boot testing
non minimal profiles testing
more tests for the above

I'll likely add the above if any interest is shown