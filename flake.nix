{
  description = "Tow-Boot firmware for NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-systems.url = "github:nix-systems/default";
    tow-boot.url = "github:Tow-Boot/Tow-Boot?ref=release-2023.07-007";
    tow-boot.flake = false;
  };

  outputs = inputs@{ self, flake-parts, nix-systems, tow-boot, ... }:
  let

    # Rewriting original Tow-Boot config evaluation to make it pure
    allTowBootDevices = builtins.filter (d: builtins.pathExists ("${tow-boot}/boards/${d}/default.nix")) (builtins.attrNames (builtins.readDir "${tow-boot}/boards"));
    evalConfig = import "${toString inputs.nixpkgs}/nixos/lib/eval-config.nix";
    modulesFromNixpkgs = map (module: "${toString inputs.nixpkgs}/nixos/modules/${module}");
    evalTowBootConfig = { device, system, pkgs ? null, config ? {} }: evalConfig {
      inherit system pkgs;
      baseModules = [
        "${tow-boot}/modules"
      ] ++ (modulesFromNixpkgs [
        "misc/assertions.nix"
        "misc/nixpkgs.nix"
      ]);
      modules = [
        { imports = [("${tow-boot}/boards/${device}")]; }
        config
      ];
    };

    allTowBootDeviceConfigurations = { system ? null, pkgs ? null }: builtins.listToAttrs (builtins.map (device: {
        name = device;
        value = evalTowBootConfig {
          inherit device system;
          config = { lib, config, ... }: {
            nixpkgs = let
              crossSystem = lib.systems.elaborate config.system.system;
            in {
              pkgs = if (builtins.isNull pkgs) then (import inputs.nixpkgs { inherit system crossSystem; }) else pkgs;
            };
          };
        };
      }) allTowBootDevices);

    # NixOS modules for firmware config
    allNixosModuleNames = builtins.filter (d: builtins.pathExists ("${self}/modules/${d}/default.nix")) (builtins.attrNames (builtins.readDir ./modules));
    allNixosModules = builtins.listToAttrs (builtins.map (m: { name = m; value = import "${self}/modules/${m}/default.nix" inputs; }) allNixosModuleNames);
  in {
    # Expose internal functions. Used within NixOS modules.
    lib = { inherit allTowBootDeviceConfigurations ; };
  } // flake-parts.lib.mkFlake { inherit inputs; } {
    systems = import "${nix-systems}/default.nix";

    # NixOS modules intended to make `boot.loader.tow-boot.<device>` available.
    flake.nixosModules = allNixosModules // {
      # default is just all modules combined
      default.imports = builtins.attrValues allNixosModules;
    };

    # Nixpkgs overlays for putting all Tow-Boot device configurations under pkgs.tow-boot
    # Be warned, Tow-Boot configurations are completely different from NixOS configurations, so putting these there is kinda wack. But where else ¯\_(ツ)_/¯
    flake.overlays.tow-boot = (final: prev: {
      tow-boot = allTowBootDeviceConfigurations { inherit (prev) system; };
    });
    flake.overlays.default = self.overlays.tow-boot;

    # Expose all Tow-Boot device configurations, in case someone simply just want Tow-Boot in flake format (against devs wishes).
    perSystem = { pkgs, self', inputs', system, ... }: {
      formatter = pkgs.nixpkgs-fmt;
      legacyPackages.tow-boot = builtins.listToAttrs (builtins.map (device: {
        name = device;
        value = evalTowBootConfig {
          inherit device system;
          config = { lib, config, ... }: {
            nixpkgs = let
              crossSystem = lib.systems.elaborate config.system.system;
            in {
              pkgs = import inputs.nixpkgs { inherit system crossSystem; };
            };
          };
        };
      }) allTowBootDevices);
    };
  };
}
