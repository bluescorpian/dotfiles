# Disk layout for Hetzner CX33 (single /dev/sda disk, GPT, EFI + BIOS compatible)
#
# disko lays this out at install time only, so a Hetzner disk upgrade grows the
# block device and stops there — `root` says 100%, but the partition keeps
# describing the old boundary until someone extends it by hand (sfdisk -N 3,
# partx -u, resize2fs, all online). Rebuilding does not do it for you.
{ lib, ... }:
{
  disko.devices = {
    disk.disk1 = {
      device = lib.mkDefault "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02"; # BIOS boot partition
          };
          esp = {
            name = "ESP";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
