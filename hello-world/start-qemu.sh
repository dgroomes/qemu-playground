#!/usr/bin/env bash
# Boot the Ubuntu base image in the foreground and run the hello-world demo.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
artifacts_dir="${script_dir}/artifacts"
guest_share_dir="${script_dir}/guest-share"

base_image="${artifacts_dir}/resolute-server-cloudimg-arm64.qcow2"
seed_iso="${artifacts_dir}/seed.iso"
serial_log="${artifacts_dir}/serial.log"
efi_vars="${artifacts_dir}/edk2-aarch64-vars.fd"

if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
    printf 'error: required command not found: qemu-system-aarch64\n' >&2
    exit 1
fi

if [[ ! -f "${base_image}" || ! -f "${seed_iso}" ]]; then
    printf 'error: build artifacts are missing. Run ./build.sh first.\n' >&2
    exit 1
fi

# Locate the EDK2 UEFI firmware files that ship with QEMU/Homebrew.
find_qemu_data_file() {
    local file_name="$1"
    local qemu_data_dir

    while IFS= read -r qemu_data_dir; do
        if [[ -f "${qemu_data_dir}/${file_name}" ]]; then
            printf '%s\n' "${qemu_data_dir}/${file_name}"
            return 0
        fi
    done < <(qemu-system-aarch64 -L help)

    printf 'error: could not find QEMU data file: %s\n' "${file_name}" >&2
    exit 1
}

efi_code="$(find_qemu_data_file edk2-aarch64-code.fd)"
efi_vars_template="$(find_qemu_data_file edk2-arm-vars.fd)"

mkdir -p "${artifacts_dir}"
# Truncate the serial log in place (do not unlink it) so a `tail -f` started in another
# terminal keeps following the same file across runs.
: > "${serial_log}"
rm -f "${efi_vars}"
cp "${efi_vars_template}" "${efi_vars}"

printf 'Starting QEMU. Serial log: %s\n' "${serial_log}"
printf 'QEMU exits when the guest powers off.\n'

qemu_args=(
    # Pick QEMU's generic ARM virtual board. It is not emulating a Raspberry Pi or a specific server.
    # hvf asks macOS Hypervisor.framework to run the ARM guest with hardware acceleration on Apple Silicon.
    -machine "virt,accel=hvf"

    # Give the guest 1 GiB of RAM. This is enough for the Ubuntu cloud image used by this demo.
    -m "1024"

    # Give the guest several virtual CPUs so early boot and cloud-init parallelize.
    -smp "4"

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

    # Boot the downloaded Ubuntu cloud image directly as a virtio block device.
    -drive "file=${base_image},format=qcow2,if=virtio"

    # Send all guest disk writes to a throwaway temp file instead of the image. The base image stays
    # pristine and every run starts fresh, so we don't need a separate overlay file.
    -snapshot

    # Attach the cloud-init NoCloud seed ISO. The guest sees this as a CD-ROM labeled cidata.
    # That seed tells the guest how to mount the host share, run the demo script, and power off.
    -cdrom "${seed_iso}"

    # Export a host directory into the guest over QEMU's 9p filesystem device.
    # local,path=... means "share this host filesystem path".
    # The mount_tag is the name cloud-init mounts inside the guest: qemu_host -> /mnt/qemu-host.
    # security_model=mapped-xattr lets a non-root host user share files with the guest without preserving guest UIDs directly.
    # id=qemu_host gives this filesystem device an internal QEMU name.
    -virtfs "local,path=${guest_share_dir},mount_tag=qemu_host,security_model=mapped-xattr,id=qemu_host"

    # No network device: the demo payload comes from the 9p host share, and we power off in cloud-init's
    # early bootcmd stage before anything would wait on the network. cloud-init network config is disabled
    # in user-data to match.

    # Do not reboot after guest shutdown. When cloud-init powers off Ubuntu, QEMU exits.
    -no-reboot
)

# Run QEMU in the foreground. It exits on its own when the guest powers off.
# To stop it early, press Ctrl+C.
exec qemu-system-aarch64 "${qemu_args[@]}"
