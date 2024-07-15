# Use this module through flake oututs.nixosModules.raspberry-pi

# TODO:
# Better config.txt, maybe in the format of
# { filters = [ "all" ]; config = { something = 1; }; priority = 100; }
# { filters = [ "pi4" ]; config = { something = 1; }; priority = 100; }
# extraConfig = "[none]\nsomething=2";
# "all" filter should go first, and be prepended to all other filters (I guess)
# Add checks for line length
# Comments?

# TODO:
# Option to bundle firmware to boot.img
# Useful for secure boot

# TODO:
# Figure out DTB and overlays. Do we need to configure those here? Why not?
# Uhm maybe have a list of selectable overlays, and include those automatically, and configure them automatically as well.


{ self, nixpkgs, tow-boot, ... }: # flake parameters
let
  evalConfig = import "${toString nixpkgs}/nixos/lib/eval-config.nix";
in
{ config, pkgs, lib, ... }: # nixos module parameters
let
  tow-boot-binaries = let
    dummyConfig = evalConfig {
      inherit (pkgs) system;
      inherit pkgs;
      baseModules = [
        "${tow-boot}/modules"
        "${nixpkgs}/nixos/modules/misc/assertions.nix"
        "${nixpkgs}/nixos/modules/misc/nixpkgs.nix"
      ];
      modules = [
        { imports = [("${tow-boot}/boards/raspberryPi-aarch64")]; }
      ];
    };
    inherit (dummyConfig.config.helpers) composeConfig;
    tow-boot-bin = id: defconfig: "${(composeConfig {
      config = {
        device.identifier = id;
        Tow-Boot.defconfig = defconfig;
      };
    }).config.Tow-Boot.outputs.firmware}/binaries/Tow-Boot.noenv.bin";
  in {
    raspberryPi-0 = tow-boot-bin "raspberryPi-0" "rpi_0_w_defconfig";
    raspberryPi-2 = tow-boot-bin "raspberryPi-2" "rpi_2_defconfig";
    raspberryPi-3 = tow-boot-bin "raspberryPi-3" "rpi_3_defconfig";
    raspberryPi-4 = tow-boot-bin "raspberryPi-4" "rpi_4_defconfig";
  };

  rpi-version-to-dtb-table = {
    "a" = [ ];
    "a+" = [ ];
    "b" = [ "bcm2708-rpi-b-rev1" "bcm2708-rpi-b" ];
    "b+" = [ "bcm2708-rpi-b-plus" ];
    "2b" = [ "bcm2709-rpi-2-b" "bcm2710-rpi-2-b" ];
    "3" = [ "bcm2710-rpi-3-b" ];
    "3b" = [ "bcm2710-rpi-3-b-plus" ];
    "4b" = [ "bcm2711-rpi-4-b" ];
    "400" = [ "bcm2711-rpi-400" ];
    "5b" = [ "bcm2712-rpi-5-b" "bcm2712d0-rpi-5-b" ];
    "zero" = [ "bcm2708-rpi-zero-w" "bcm2708-rpi-zero" ];
    "zero2" = [ "bcm2710-rpi-zero-2-w" "bcm2710-rpi-zero-2" ];
    "cm1" = [ "bcm2708-rpi-cm" ];
    "cm2" = [ "bcm2709-rpi-cm2" ];
    "cm3" = [ "bcm2710-rpi-cm3" ];
    "cm4" = [ "bcm2711-rpi-cm4-io" "bcm2711-rpi-cm4" "bcm2711-rpi-cm4s" ];
    "cm4s" = [ "bcm2711-rpi-cm4s" ];
    "cm5" = [ "bcm2712-rpi-cm5-cm4io" "bcm2712-rpi-cm5-cm5io" ];
  };
  all-rpi-versions = builtins.attrNames rpi-version-to-dtb-table;

  cfg = config.boot.firmware.tow-boot.raspberry-pi;

  install-tow-boot-script = pkgs.writeShellScript "install-tow-boot.sh" ''
    set -eufo pipefail
    echo Installing Tow-Boot for Raspberry Pi >&2
    echo "$0"
    FIRMWARE_INSTALL_PATH="''${1:-"${cfg.install-path}"}"

    ${lib.concatStrings (lib.mapAttrsToList (n: v: ''
      ${pkgs.coreutils}/bin/install -D "${v}" "$FIRMWARE_INSTALL_PATH/${n}"
    '') cfg.files)}

    ${if cfg.overlays.enable == true then ''
      find ${pkgs.raspberrypifw}/share/raspberrypi/boot/overlays -type f -exec install -D {} "$FIRMWARE_INSTALL_PATH/overlays" \;
    '' else ""}

    echo Finished installing Tow-Boot for Raspberry Pi >&2
  '';

in {
  options.boot.firmware.tow-boot.raspberry-pi = {
    enable = lib.mkEnableOption "Raspberry Pi Tow-Boot firmware";
    install-script = lib.mkOption {
      description = "Script to run to install Tow-Boot.";
      readOnly = true;
      internal = true;
      default = install-tow-boot-script;
    };
    devices = lib.mkOption {
      description = ''
        What devices to support. Defaults to `[ "3" "3b" "4b" "400" ]`.
        Specifying specific device(s) may reduce firmware partition size.

        NOTE: Tow-Boot only _experimentally_ supports Raspberry Pi 3 and 4 as of writing this.
      '';
      type = lib.types.listOf (lib.types.enum all-rpi-versions);
      default = [ "3" "3b" "4b" "400" ];
    };
    files = lib.mkOption {
      description = "Files to be placed on firmware partition.";
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.pathInStore lib.types.path lib.types.package ]);
    };
    config-txt = lib.mkOption {
      readOnly = true;
      internal = true;
      default = pkgs.writeText "rpi-config.txt" (lib.generators.toINI {} cfg.config);
    };
    install-path = lib.mkOption {
      type = lib.types.str;
      default = "/boot/firmware";
    };
    gic.enable = lib.mkOption {
      description = "Enable GIC-400. Only applicable to Raspberry Pi 4.";
      type = lib.types.bool;
      default = builtins.elem "4b" cfg.devices;
    };
    overlays.enable = lib.mkOption {
      description = "Install overlays folder to firmware partition.";
      type = lib.types.bool;
      default = true;
    };
    config = lib.mkOption {
      description = "Configuration entries for config.txt. Automatically generated, but possible to override";
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = {};
    };
    installOnActivation = lib.mkOption {
      description = "Wether to install Tow-Boot at system activation. Not recommended, but on first install it might be needed.";
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      # Add Tow-Boot overlay, enabling `pkgs.tow-boot`.
      self.overlays.default
    ];

    boot.firmware.tow-boot.raspberry-pi = lib.mkMerge [
      {
        # Applicable to all
        config.all.arm_64bit = "1";
        config.all.enable_uart = "1";
        config.all.avoid_warnings = "1";

        files."config.txt" = cfg.config-txt;
      }

      # GIC configuration, only applicable to Raspberry Pi 4
      (lib.mkIf cfg.gic.enable {
        config.pi4.enable_gic = 1;
        config.pi4.armstub = "armstub8-gic.bin";
        files."armstub8-gic.bin" = "${pkgs.raspberrypi-armstubs}/armstub8-gic.bin";
      })
      (lib.mkIf (!cfg.gic.enable) {
        config.pi4.enable_gic = 0;
        config.pi4.armstub = "armstub8.bin";
        files."armstub8.bin" = "${pkgs.raspberrypi-armstubs}/armstub8.bin";
      })

      # All versions prior to 4
      (lib.mkIf (!lib.mutuallyExclusive [ "a" "a+" "b" "b+" "2b" "3" "3b" "zero" "zero2" "cm1" "cm2" "cm3" ] cfg.devices) {
        files = {
          "fixup.dat" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup.dat";
          "fixup_x.dat" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup_x.dat";
          "fixup_db.dat" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup_db.dat";
          "fixup_cd.dat" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup_cd.dat";
          "start.elf" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/start.elf";
          "start_x.elf" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/start_x.elf";
          "start_db.elf" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/start_db.elf";
          "start_cd.elf" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/start_cd.elf";
        };
      })

      # All versions prior to 5
      (lib.mkIf (!lib.mutuallyExclusive [ "a" "a+" "b" "b+" "2b" "3" "3b" "4b" "400" "zero" "zero2" "cm1" "cm2" "cm3" "cm4" "cm4s" ] cfg.devices) {
        files."bootcode.bin" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/bootcode.bin";
      })

      # Raspberry Pi Zero (unsupported)
      (lib.mkIf (!lib.mutuallyExclusive [ "zero" ] cfg.devices) {
        files."Tow-Boot.noenv.rpi0.bin" = tow-boot-binaries.raspberryPi-0;
        config.pi0.kernel = "Tow-Boot.noenv.rpi0.bin";
      })

      # Raspberry Pi 2 (unsupported)
      (lib.mkIf (!lib.mutuallyExclusive [ "2b" "cm2" ] cfg.devices) {
        files."Tow-Boot.noenv.rpi2.bin" = tow-boot-binaries.raspberryPi-2;
        config.pi4.kernel = "Tow-Boot.noenv.rpi4.bin";
      })

      # Raspberry Pi 3
      (lib.mkIf (!lib.mutuallyExclusive [ "3" "3b" "cm3" ] cfg.devices) {
        files."Tow-Boot.noenv.rpi3.bin" = tow-boot-binaries.raspberryPi-3;
        config.pi3.kernel = "Tow-Boot.noenv.rpi3.bin";
      })

      # Raspberry Pi 4
      (lib.mkIf (!lib.mutuallyExclusive [ "4b" "400" "cm4" "cm4s" ] cfg.devices) {
        config.pi4.kernel = "Tow-Boot.noenv.rpi4.bin";
        files = {
          "Tow-Boot.noenv.rpi4.bin" = tow-boot-binaries.raspberryPi-4;
          "fixup4.dat" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup4.dat";
          "fixup4x.dat" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup4x.dat";
          "fixup4db.dat" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup4db.dat";
          "fixup4cd.dat" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup4cd.dat";
          "start4.elf" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/start4.elf";
          "start4x.elf" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/start4x.elf";
          "start4db.elf" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/start4db.elf";
          "start4cd.elf" = "${pkgs.raspberrypifw}/share/raspberrypi/boot/start4cd.elf";
        };
      })

      # Include applicable device tree blobs
      {
        files =
          let
            version-with-dtb-attrsets = lib.filterAttrs (n: v: builtins.elem n cfg.devices) rpi-version-to-dtb-table;
            dtbs = lib.unique (lib.flatten (builtins.attrValues version-with-dtb-attrsets));
          in
            builtins.listToAttrs (builtins.map (device: { name = "${device}.dtb"; value = "${pkgs.raspberrypifw}/share/raspberrypi/boot/${device}.dtb"; }) dtbs);
      }
    ];

    system.activationScripts.rpi-tow-boot-installer = lib.mkIf cfg.installOnActivation {
      deps = [];
      supportsDryActivation = false;
      text = "${install-tow-boot-script}";
    };
  };
}
