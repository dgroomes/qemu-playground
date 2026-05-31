#!/usr/bin/env bash
# Run the QEMU Hello World demo and stream the guest serial console.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
artifacts_dir="${script_dir}/artifacts"
guest_share_dir="${script_dir}/guest-share"

disk_image="${artifacts_dir}/hello.qcow2"
seed_iso="${artifacts_dir}/seed.iso"
serial_log="${artifacts_dir}/serial.log"
pid_file="${artifacts_dir}/qemu.pid"
efi_vars="${artifacts_dir}/edk2-aarch64-vars.fd"
run_timeout_seconds="${RUN_TIMEOUT_SECONDS:-180}"

require_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'error: required command not found: %s\n' "${command_name}" >&2
        exit 1
    fi
}

cleanup() {
    if [[ -n "${watchdog_pid:-}" ]] && kill -0 "${watchdog_pid}" >/dev/null 2>&1; then
        kill "${watchdog_pid}" >/dev/null 2>&1 || true
        wait "${watchdog_pid}" >/dev/null 2>&1 || true
    fi
    if [[ -n "${tail_pid:-}" ]] && kill -0 "${tail_pid}" >/dev/null 2>&1; then
        kill "${tail_pid}" >/dev/null 2>&1 || true
        wait "${tail_pid}" >/dev/null 2>&1 || true
    fi
    if [[ -n "${qemu_pid:-}" ]] && kill -0 "${qemu_pid}" >/dev/null 2>&1; then
        kill "${qemu_pid}" >/dev/null 2>&1 || true
        wait "${qemu_pid}" >/dev/null 2>&1 || true
    fi
    rm -f "${pid_file}"
}

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

trap cleanup EXIT

"${script_dir}/build.sh"

require_command qemu-system-aarch64
efi_code="$(find_qemu_data_file edk2-aarch64-code.fd)"
efi_vars_template="$(find_qemu_data_file edk2-arm-vars.fd)"

mkdir -p "${artifacts_dir}"
rm -f "${pid_file}" "${serial_log}" "${efi_vars}"
: > "${serial_log}"
cp "${efi_vars_template}" "${efi_vars}"

printf 'Starting QEMU. Serial log: %s\n' "${serial_log}"

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

    # Connect the guest's serial port to a host file. The script tails this file so you can watch boot progress.
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

    # Do not reboot after guest shutdown. When cloud-init powers off Ubuntu, QEMU exits and this script can finish.
    -no-reboot
)

qemu-system-aarch64 "${qemu_args[@]}" &

qemu_pid="$!"
printf '%s\n' "${qemu_pid}" > "${pid_file}"

tail -n +1 -f "${serial_log}" &
tail_pid="$!"

(
    sleep "${run_timeout_seconds}"
    if kill -0 "${qemu_pid}" >/dev/null 2>&1; then
        printf '\nerror: QEMU did not exit within %s seconds; killing it. Serial log: %s\n' \
            "${run_timeout_seconds}" "${serial_log}" >&2
        kill "${qemu_pid}" >/dev/null 2>&1 || true
    fi
) &
watchdog_pid="$!"

# Why is +e needed? Does wait have a non-0 exit when the PID it's waiting for had a non-0 exit?
set +e
wait "${qemu_pid}"
qemu_status="$?"
set -e

cleanup

if [[ "${qemu_status}" -ne 0 ]]; then
    printf 'error: QEMU exited with status %s\n' "${qemu_status}" >&2
    exit "${qemu_status}"
fi

if grep -q 'Hello from qemu-playground inside Ubuntu' "${serial_log}"; then
    printf '\nDemo completed. Serial log: %s\n' "${serial_log}"
else
    printf '\nerror: the expected hello message was not found in %s\n' "${serial_log}" >&2
    exit 1
fi
