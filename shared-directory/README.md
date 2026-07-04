# shared-directory

---
**WARNING**: Mostly unedited AI output.

This is still a useful reference, but heavily discount it and I might repurpose it or delete it.

I might be bottoming out on my current arc of QEMU learning. I captured the hello world references I wanted. But ultimately
QEMU doesn't have a state-of-the-art file sharing story on macOS because it uses the legacy 9P solution. This is unfortunate
because Apple's virtualization framework does have a better model here, and QEMU doesn't use that. But Lima does, and
so does Tart (signed binary!), and I would think UTM does too.

---

Share a host directory into a Linux guest VM over virtio-9p.


## Overview

A dev box VM is only useful to me if the guest can see my files. I want to edit source code on the host (in my normal
editor, backed by my normal Git setup) and have the guest see those edits live, and I want files the guest writes to
show up on the host.

QEMU's most first-principles answer to this is [9p][9p], a network filesystem protocol from the Plan 9 operating
system. QEMU speaks the protocol on the host side, serving a directory of our choosing, and the Linux kernel has a 9p
client built in (as modules, in Alpine's case). Instead of an actual network, the protocol rides over a
[virtio](https://wiki.osdev.org/Virtio) device, which is essentially a shared-memory channel between QEMU and the
guest kernel.

This demo boots the same interactive Alpine ISO as the `boot-from-iso/` subproject, plus two flags that export a host
directory, and then we mount it from inside the guest with one command. The [`hello-world-9p/`](../hello-world-9p/)
subproject is the extreme version of this idea, where the host directory is the guest's entire root filesystem.


## Instructions

1. Assumptions: macOS, Apple Silicon, Homebrew-installed QEMU
2. Download an Alpine Linux ISO (~90 MB)
   - ```shell
     curl -LO https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/aarch64/alpine-virt-3.24.1-aarch64.iso
     ```
3. Create the directory to share, and put a file in it
   - ```shell
     mkdir shared
     echo "hello from the host" > shared/hello-from-host.txt
     ```
4. Boot the virtual machine
   - ```shell
     qemu-system-aarch64 \
       -machine virt,accel=hvf \
       -cpu host \
       -m 512 \
       -bios "/opt/homebrew/share/qemu/edk2-aarch64-code.fd" \
       -cdrom alpine-virt-3.24.1-aarch64.iso \
       -fsdev local,id=shared0,path=shared,security_model=none \
       -device virtio-9p-pci,fsdev=shared0,mount_tag=shared \
       -nographic
     ```
   - The base flags are explained in `boot-from-iso/`. The two new ones come as a pair: a *backend* (the host-side
     resource) and a *device* (the virtual hardware the guest sees), joined by the `shared0` id.
   - `-fsdev local,id=shared0,path=shared,...` is the backend: serve the host directory `./shared` over 9p.
     `security_model=none` means QEMU reads and writes host files plainly, as the user running QEMU, and doesn't try
     to track guest-side ownership. Simplest model, fine for a single-user dev share.
   - `-device virtio-9p-pci,fsdev=shared0,mount_tag=shared` is the device: a PCI device wired to that backend. The
     `mount_tag` is the name the guest will use to refer to the share, like a device name.
5. Log in as `root` (no password), then mount the share
   - ```shell
     mkdir /mnt/shared
     mount -t 9p -o trans=virtio shared /mnt/shared
     ```
   - `-t 9p` is the filesystem type, `trans=virtio` says the protocol rides the virtio device rather than a TCP
     connection, and `shared` is the `mount_tag` from the QEMU command.
   - Note what we did *not* have to do: load any drivers. Alpine ships the 9p client as kernel modules, and the live
     system autoloads them when we ask for the mount. (Contrast with `hello-world-9p/`, which has to hand-carry those
     modules in an initramfs because there the 9p mount must happen before a root filesystem even exists.)
6. Read the host's file from the guest
   - ```shell
     cat /mnt/shared/hello-from-host.txt
     ```
7. Write a file from the guest
   - ```shell
     echo "hello from the guest" > /mnt/shared/hello-from-guest.txt
     ```
8. Verify on the host
   - In another terminal on your Mac:
   - ```shell
     cat shared/hello-from-guest.txt
     ```
   - The share is live in both directions. Edit a file on the host and `cat` it again in the guest — no rebuild, no
     re-mount.
9. Shut the machine down
   - ```shell
     poweroff
     ```


## Wish List

General clean-ups, TODOs and things I wish to implement for this project:

- [ ] ABANDON (for now — researched Jul 2026, not viable on a macOS host) Explore [virtiofs](https://virtio-fs.gitlab.io/)
  as the modern, faster alternative to 9p. Unlike 9p (which QEMU serves in-process), virtiofs needs a separate daemon
  (`virtiofsd`) speaking vhost-user over a socket, with guest RAM in shared memory so the daemon can access it
  directly. The official `virtiofsd` is Linux-only (namespaces, epoll, openat2); macOS support is an open upstream
  issue ([virtiofsd#169](https://gitlab.com/virtio-fs/virtiofsd/-/issues/169)). Homebrew's QEMU doesn't even compile
  in the `vhost-user-fs-pci` device on macOS, though the `memory-backend-shm` groundwork has landed. Note: virtiofs
  *does* work great on macOS via Apple's Virtualization.framework (Docker Desktop, Lima) — a different VMM, out of
  scope here. Revisit on a Linux host, where `virtiofsd` is a package install away.
- [ ] Understand the `security_model` options (`none`, `mapped-xattr`, `mapped-file`, `passthrough`) more deeply, and
  what happens with ownership when a multi-user guest writes to the share.


## Reference

- [QEMU 9p / virtfs documentation](https://wiki.qemu.org/Documentation/9psetup)
- [Linux kernel 9p client documentation](https://www.kernel.org/doc/html/latest/filesystems/9p.html)

[9p]: https://en.wikipedia.org/wiki/9P_(protocol)
