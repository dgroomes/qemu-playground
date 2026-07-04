# direct-kernel-boot

Boot a Linux kernel directly and bypass UEFI and a bootloader.


## Overview

A physical computer boots through firmware and a bootloader before Linux ever runs. QEMU, and other Virtual Machine
Monitors (VMM) can skip those steps to achieve a much faster boot into the guest OS. In QEMU, this feature is called ["direct Linux boot"](https://www.qemu.org/docs/master/system/linuxboot.html).

This demo boots [Alpine Linux](https://alpinelinux.org/)'s stock kernel, tells it to run a user program, and powers off. This all happens in a fraction of a second.


## Instructions

1. Assumptions: macOS, Apple Silicon, Homebrew-installed QEMU
2. Download Alpine's kernel and initramfs (~20 MB total)
   - ```shell
     curl -LO https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/aarch64/netboot-3.24.1/vmlinuz-virt
     curl -LO https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/aarch64/netboot-3.24.1/initramfs-virt
     ```
3. Boot, run a user program, and exit
   - ```shell
     qemu-system-aarch64 \
       -machine virt,accel=hvf \
       -cpu host \
       -m 512 \
       -kernel vmlinuz-virt \
       -initrd initramfs-virt \
       -append 'console=ttyAMA0 rdinit=/bin/sh -- -c "echo hi world; busybox poweroff -f"' \
       -nographic -no-reboot
     ```
   - After a second you should see something like the following.
   - ```text
     [    0.000000] Booting Linux on physical CPU 0x0000000000 [0x610f0000]
     ... omitted ...
     [    0.120036] Run /bin/sh as init process
     hi world
     [    0.122112] reboot: Power down
     ```
   - Success! We've run a user program (a shell snippet that says "hi world") in a Linux VM without the overhead of UEFI and the bootloader. Let's understand some of the [QEMU flags](https://www.qemu.org/docs/master/system/invocation.html).
   - `-kernel vmlinuz-virt` points to the Linux kernel image file that we downloaded, so that QEMU can boot directly into it
   - `-initrd initramfs-virt` loads a a small starter filesystem into memory alongside the kernel. Alpine's stock one
     contains a shell (`/bin/sh`, provided by [BusyBox](https://busybox.net/)), which is all we need
   - `-append '...'` sets the kernel command line. The `console=ttyAMA0` means print to the serial port. `rdinit=/bin/sh` means that instead of a normal init system, run the shell as the first process (PID 1). And finally we pass our user program.
   - `-no-reboot` when the guest powers off, QEMU exits instead of restarting the machine.
