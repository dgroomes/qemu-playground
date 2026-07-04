# user-mode-networking

---
WARNING: Mostly unedited AI output.

This is still a useful reference, but heavily discount it and I might repurpose it or delete it.

One thing that's a little annoying is that QEMU supports vmnet but QEMU distributed via Homebrew isn't codesigned by an
Apple Developer account, and so you can't use the network entitlement without using root. By contast, Tart and UTM
distribute their binaries signed. I'd way prefer to use vment than the now legacy 9P or the out-of-the-way gVisor thing
apparently I could do (similar to what Lima is doing?). I dont' really get how it all works. Also it hallucinated that
passt is read to go on macOS, it is not.

---

Give a Linux guest VM outbound internet and forward a host port to a web server running in the guest.


## Overview

The other half of my dev box story is networking. Two things have to work:

- **Guest → out.** The guest needs to reach the internet, e.g. to install packages or `git push`.
- **Host → guest.** When I run a web server inside the guest, I want to open it in the browser on my Mac.

QEMU's most first-principles answer is [user-mode networking][qemu-net] (often called "slirp" after the library that
implements it). There is no real network interface involved and no admin privileges needed: QEMU itself acts as the
guest's entire network. It plays the role of gateway, DHCP server, and DNS forwarder on a make-believe `10.0.2.0/24`
network, and it translates the guest's outbound TCP/UDP traffic into ordinary sockets on the host — much like how
every process on your Mac can open network connections without owning a network card. The inbound direction doesn't
exist by default (the guest is unreachable, like a machine behind a home router), so we punch a hole with a `hostfwd`
port-forwarding rule.

This demo boots the same interactive Alpine ISO as the `boot-from-iso/` subproject with one network device attached,
proves outbound connectivity with `wget`, and then serves a web page from the guest to your Mac's browser.


## Instructions

1. Assumptions: macOS, Apple Silicon, Homebrew-installed QEMU
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
       -netdev user,id=net0,hostfwd=tcp::8080-:8000 \
       -device virtio-net-pci,netdev=net0 \
       -nographic
     ```
   - The base flags are explained in `boot-from-iso/`. The two new ones come as a pair: a *backend* (host-side
     plumbing) and a *device* (the virtual hardware the guest sees), joined by the `net0` id.
   - `-netdev user,id=net0,...` is the backend: QEMU's user-mode network. `hostfwd=tcp::8080-:8000` adds the one
     inbound rule: connections to port 8080 on the Mac get forwarded to port 8000 in the guest.
   - `-device virtio-net-pci,netdev=net0` is the device: a paravirtualized network card wired to that backend. The
     guest sees it as an ordinary `eth0`.
4. Log in as `root` (no password), then bring up the network
   - ```shell
     ifconfig eth0 up && udhcpc -i eth0
     ```
   - `udhcpc` is BusyBox's DHCP client. It asks for an address and QEMU's built-in DHCP server answers:
   - ```text
     udhcpc: lease of 10.0.2.15 obtained from 10.0.2.2, lease time 86400
     ```
   - These addresses are QEMU conventions: the guest is always `10.0.2.15`, the gateway (QEMU itself) is `10.0.2.2`,
     and DNS is at `10.0.2.3`. The DHCP lease configures all three.
5. Prove outbound connectivity
   - ```shell
     wget -q -O - https://www.wikipedia.org
     ```
   - HTML from the real internet, fetched from inside the guest. (Tip: `ping` is a bad connectivity test here — ICMP
     doesn't travel well through user-mode networking. Use a TCP tool like `wget`.)
6. Serve a web page from the guest
   - The `httpd` applet isn't in Alpine's default BusyBox build, so install the `busybox-extras` package. This is also
     a nice second proof of outbound networking.
   - ```shell
     apk add --repository https://dl-cdn.alpinelinux.org/alpine/v3.24/main busybox-extras
     mkdir /tmp/www
     echo '<h1>hi from the guest VM</h1>' > /tmp/www/index.html
     httpd -p 8000 -h /tmp/www
     ```
7. Browse from your Mac
   - Open <http://localhost:8080> in your browser, or in another terminal:
   - ```shell
     curl http://localhost:8080
     ```
   - Your Mac connected to `localhost:8080`, QEMU matched the `hostfwd` rule and relayed the connection to
     `10.0.2.15:8000` in the guest, and the guest's web server answered. This is the "develop in the guest, browse
     from the host" loop.
8. Shut the machine down
   - ```shell
     poweroff
     ```


## Wish List

General clean-ups, TODOs and things I wish to implement for this project:

- [ ] Forward port 22 (`hostfwd=tcp::2222-:22`) and SSH into the guest. This is the real dev box workflow — the serial
  console is charming but SSH gets me a proper terminal, `scp`, and remote-editing from the host.
- [ ] Try `vmnet-shared`, the macOS-native step up (in QEMU since 7.1). The macOS kernel switches the packets and the
  guest gets a real, directly-addressable IP on a macOS-managed subnet — no `hostfwd` holes needed. The cost: vmnet
  requires root (or an Apple entitlement only granted to signed apps like UTM), so it means `sudo qemu-system-...`.
  Modes: `vmnet-shared` (NAT, host can reach guest), `vmnet-host` (host-only), `vmnet-bridged` (guest joins the LAN).
- [ ] Try `passt`, the modern successor to slirp from the podman/KubeVirt world. Same no-root NAT topology, but the
  network stack runs in a separate sandboxed process (slirp parses guest packets inside QEMU, and has the CVE history
  to show for it) and forwards at layer 4, which is faster. QEMU 11 has a native `-netdev passt` backend and Homebrew
  now packages passt for macOS.
- [ ] Non-options on macOS, noted for completeness: `tap` (the classic Linux answer, standard on Linux hosts via
  bridge + vhost-net, but needs a kernel extension on macOS and kexts are deprecated), `vde` (2000s-era virtual
  switch), `socket`/`stream`/`dgram` (point-to-point plumbing for VM-to-VM wiring, not host connectivity).


## Reference

- [QEMU networking documentation][qemu-net]
- [QEMU networking wiki, "slirp" section](https://wiki.qemu.org/Documentation/Networking#User_Networking_.28SLIRP.29)
- [Alpine Linux packages](https://pkgs.alpinelinux.org/) — where to find which package provides `httpd`
  (`busybox-extras`)

[qemu-net]: https://www.qemu.org/docs/master/system/devices/net.html
