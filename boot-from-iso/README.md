# boot-from-iso

Boot a Linux guest VM from an Alpine ISO.


## Overview

This is a "hello world" QEMU example. We use QEMU to virtualize a machine and then do something that feels a lot like
the real-world experience of "flashing the BIOS" and inserting a Linux distro's installation CD.

Specifically, we load UEFI firmware built by [EDK2](https://github.com/tianocore/edk2) and attach an [Alpine Linux](https://alpinelinux.org/)
live ISO as a virtual CD. This is enough software for the virtual computer to do its thing and bootstrap us into an
interactive Linux commandline shell where we can `echo` a friendly message.

This is about as simple and relatable as I could make a QEMU example project for my own reference.


## Instructions

1. Assumptions
   - I used macOS on Apple Silicon
   - I installed QEMU from Homebrew with the following command.
   - ```shell
     brew install qemu
     ```
2. Download an Alpine Linux ISO (~90 MB)
   - ```shell
     curl -LO https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/aarch64/alpine-virt-3.24.1-aarch64.iso
     ```
3. Boot the virtual machine
   - ```shell
     qemu-system-aarch64 \
       -machine virt,accel=hvf \
       -cpu host \
       -m 512 \
       -bios "/opt/homebrew/share/qemu/edk2-aarch64-code.fd" \
       -cdrom alpine-virt-3.24.1-aarch64.iso \
       -nographic
     ```
   - Linux boot messages scroll by for about ten seconds, ending at a login prompt. Let's understand some of the [QEMU flags](https://www.qemu.org/docs/master/system/invocation.html).
   - `-machine virt` says to use the "virt" machine type which is QEMU's model of a generic ARM computer.
   - `accel=hvf` enables macOS's Hypervisor.framework for faster guest CPU execution.
   - `-bios .../edk2-aarch64-code.fd` tells QEMU to load UEFI firmware conveniently bundled with Homebrew's QEMU package.
   - `-cdrom ...` attaches our downloaded Alpine Linux ISO as a CD
4. Log in
   - Type `root` and press enter. There is no password. It should look like the following.
   - ```text
     localhost login: root
     Welcome to Alpine!
     ```
5. Say hello
   - ```shell
     echo "hi there"
     ```
   - We've done it! We've followed a simple path to boot and use a Linux virtual machine with QEMU. 
6. Shut the machine down
   - ```shell
     poweroff
     ```


## Reference

- [Alpine Linux downloads](https://alpinelinux.org/downloads/)
  - This demo uses the "Virtual" flavor, built for VMs.
