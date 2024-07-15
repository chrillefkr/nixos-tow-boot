{
  description = "Example nixos-tow-boot configuration for raspberry pi";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    nixos-tow-boot.url = "github:chrillefkr/nixos-tow-boot";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = inputs@{ self, nixpkgs, nixos-tow-boot, disko, nixos-hardware, ... }: {
    disko = disko;
    nixosConfigurations = {
      example = inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          nixos-hardware.nixosModules.raspberry-pi-4
          nixos-tow-boot.nixosModules.default
          disko.nixosModules.disko
          ({ config, pkgs, lib, ... }: {
            system.stateVersion = lib.versions.majorMinor lib.version;
            boot = {
              consoleLogLevel = 15;
              initrd = {
                systemd = {
                  enable = true;
                  emergencyAccess = true;
                  enableTpm2 = false; # https://github.com/NixOS/nixos-hardware/issues/858
                };
              };
              firmware.tow-boot.raspberry-pi = {
                enable = true;
                devices = [ "4b" ];
                installOnActivation = true;
              };
              loader = {
                generic-extlinux-compatible = {
                  enable = true;
                };
                grub = {
                  enable = false;
                  devices = [ "nodev" ];
                  efiSupport = true;
                };
                systemd-boot.enable = false;
              };
            };
            disko.devices.disk.main ={
              device = "/dev/disk/by-id/usb-Samsung_PSSD_T7_S5TNNS0RB10072M-0:0";
              type = "disk";
              content = {
                type = "gpt";
                efiGptPartitionFirst = false;
                partitions = {
                  TOW-BOOT-FI = {
                    priority = 1;
                    type = "EF00";
                    size = "500M";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot/firmware";
                    };
                    hybrid = {
                      mbrPartitionType = "0x0c";
                      mbrBootableFlag = false;
                    };
                  };
                  ESP = {
                    priority = 2;
                    type = "EF00";
                    size = "500M";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                    };
                  };
                  root = {
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
          })
        ];
      };
    };
  };
}
