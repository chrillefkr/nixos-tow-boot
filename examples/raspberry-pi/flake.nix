{
  description = "Example nixos-tow-boot configuration for raspberry pi";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    nixos-tow-boot.url = "github:chrillefkr/nixos-tow-boot";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nixos-tow-boot, disko, nixos-hardware, ... }: {
    disko = disko;
    nixosConfigurations = {
      example = inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        #system = "x86_64-linux";
        modules = [
          nixos-hardware.nixosModules.raspberry-pi-4
          nixos-tow-boot.nixosModules.default
          disko.nixosModules.disko
          ({ config, pkgs, lib, ... }: {
            system.stateVersion = lib.versions.majorMinor lib.version;
            boot.initrd.systemd.enableTpm2 = false; # https://github.com/NixOS/nixos-hardware/issues/858
            #boot.isContainer = true;
            environment.systemPackages =
            let
              pkgsFor-x86_64-linux = import nixpkgs { system = "x86_64-linux"; };
            in [
              pkgsFor-x86_64-linux.qemu_full
              (pkgs.writeScriptBin "eh" ''
                ${pkgsFor-x86_64-linux.wrapQemuBinfmtP "qemu-aarch64-linux-binfmt-P" "${pkgsFor-x86_64-linux.qemu}/bin/qemu-aarch64"}
              '')
              pkgs.util-linux
            ];
            boot.initrd.availableKernelModules = [
              "xhci_pci"
              "nvme"
              "usb_storage"
              "sd_mod"
            ];
            #boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
            nixpkgs.config.allowUnsupportedSystem = true;
            boot.firmware.tow-boot.raspberry-pi = {
              enable = true;
              devices = [ "4b" ];
              #files.test = "/test";
              installOnActivation = true;
            };
            boot.consoleLogLevel = 15;
            boot.initrd.systemd = {
              enable = true;
              emergencyAccess = true;
            };
            boot.loader.generic-extlinux-compatible = {
              enable = true;
            };
            boot.loader.grub = {
              enable = false;
              devices = [ "nodev" ];
              efiSupport = true;
            };
            #boot.loader.systemd-boot = {
            #  enable = true;
            #};
            virtualisation.vmVariant = {
              virtualisation = {
                #graphics = true;
                diskSize = 1024 * 8;
                memorySize = 4096; # A bit more memory is usually needed when building on target (i.e. using flake)
                #diskImage = null; # Disable persistant storage
                #emptyDiskImages = [ (1024 * 5) ]; # Add one 5 GiB disk to install onto
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
        specialArgs = { inherit inputs; };
      };
    };
  };
}
