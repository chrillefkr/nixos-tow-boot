# Tow-Boot firmware for NixOS

## Disclaimer

Tow-Boot wants to be independent from distribution, and should be handled
"out-of-bounds", so using this goes against that a bit.

Though for devices with shared storage, i.e. where bootloader resides on storage
shared with bootloader and OS, this project might be useful.

Try to install Tow-Boot through their strategies if possible.

Throughout this project, Tow-Boot is referred to as firmware. It does not
replace your bootloader, e.g. GRUB, systemd-boot, etc.

## What

This project intends to expose a firmware installation script for Tow-Boot on
supported platforms.

For the moment, Raspberry Pi (3 & 4) is the only implemented platform.

## Why

Can be useful if building NixOS disks on another platform than on target
machine, where Tow-Boot (or other firmware) hasn't already been installed.

Could also be useful for changing firmware configuration from within NixOS.

## How

Firmware partition (usually mounted at `/boot/firmware`) gets populated with
Tow-Boot firmware, together with whatever else firmware files are needed to
boot; such as configuration files.

Configuration options are placed under `boot.firmware.tow-boot`, as `hardware.firmware`
is already taken.

