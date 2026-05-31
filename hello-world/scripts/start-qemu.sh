#!/usr/bin/env bash
# Start the hello-world guest in the foreground.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

require_command qemu-system-aarch64

efi_code="$(find_qemu_data_file edk2-aarch64-code.fd)"
efi_vars_template="$(find_qemu_data_file edk2-arm-vars.fd)"

if [[ ! -f "${disk_image}" || ! -f "${seed_iso}" ]]; then
    printf 'error: build artifacts are missing. Run ./build.sh first.\n' >&2
    exit 1
fi

mkdir -p "${artifacts_dir}"
rm -f "${serial_log}" "${efi_vars}"
: > "${serial_log}"
cp "${efi_vars_template}" "${efi_vars}"

printf 'Starting QEMU. Serial log: %s\n' "${serial_log}"
printf 'QEMU exits when the guest powers off.\n'

qemu_args=(
    # Pick QEMU's generic ARM virtual board. It is not emulating a Raspberry Pi or a specific server.
    # hvf asks macOS Hypervisor.framework to run the ARM guest with hardware acceleration on Apple Silicon.
    -machine "virt,accel=hvf"

    # Give the guest 1 GiB of RAM. This is enough for the Ubuntu cloud image used by this demo.
    -m "1024"

    # Give the guest one virtual CPU. More CPUs are possible, but one keeps the demo output simple.
    -smp "1"

    # Do not open a graphical display window. This VM is controlled entirely through its serial console.
    -display none

    # Disable QEMU's human monitor. The monitor is useful for interactive debugging, but this demo is script-driven.
    -monitor none

    # Connect the guest's serial port to a host file.
    -serial "file:${serial_log}"

    # ARM64 Ubuntu cloud images boot through UEFI, so QEMU needs firmware.
    # This pflash drive is the read-only EDK2 firmware code shipped with QEMU/Homebrew.
    -drive "if=pflash,format=raw,readonly=on,file=${efi_code}"

    # UEFI also expects a writable variable store for boot entries and firmware settings.
    # We copy QEMU's template on every run so the demo starts from a fresh firmware state.
    -drive "if=pflash,format=raw,file=${efi_vars}"

    # Attach the Ubuntu qcow2 overlay as a virtio block device. The overlay is writable; the base image stays cached.
    -drive "file=${disk_image},format=qcow2,if=virtio"

    # Attach the cloud-init NoCloud seed ISO. The guest sees this as a CD-ROM labeled cidata.
    # That seed tells the guest how to mount the host share, run the demo script, and power off.
    -cdrom "${seed_iso}"

    # Export a host directory into the guest over QEMU's 9p filesystem device.
    # local,path=... means "share this host filesystem path".
    # The mount_tag is the name cloud-init mounts inside the guest: qemu_host -> /mnt/qemu-host.
    # security_model=mapped-xattr lets a non-root host user share files with the guest without preserving guest UIDs directly.
    # id=qemu_host gives this filesystem device an internal QEMU name.
    -virtfs "local,path=${guest_share_dir},mount_tag=qemu_host,security_model=mapped-xattr,id=qemu_host"

    # Ubuntu cloud images start systemd-networkd-wait-online during boot. Without a NIC, this stock image waits there
    # before cloud-init reaches our hello-world command. This user-mode NIC is present only to let Ubuntu's
    # normal boot finish; the demo payload below uses the 9p host share, not the network.
    # -netdev user creates QEMU's built-in NAT-style network backend on the host side.
    # id=net0 names that backend so the virtual NIC device can attach to it.
    -netdev "user,id=net0"

    # virtio-net-pci is the guest-visible network card. netdev=net0 plugs it into the backend above.
    # romfile= disables the NIC option ROM, which avoids extra network-boot firmware behavior in this tiny demo.
    -device "virtio-net-pci,netdev=net0,romfile="

    # Do not reboot after guest shutdown. When cloud-init powers off Ubuntu, QEMU exits.
    -no-reboot
)

# Run QEMU in the foreground. It exits on its own when the guest powers off.
# To stop it early, kill it from another terminal (see README).
exec qemu-system-aarch64 "${qemu_args[@]}"
