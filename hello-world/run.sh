#!/usr/bin/env bash
# Run the QEMU Hello World demo and stream the guest serial console.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
artifacts_dir="${script_dir}/artifacts"

disk_image="${artifacts_dir}/hello.qcow2"
seed_iso="${artifacts_dir}/seed.iso"
serial_log="${artifacts_dir}/serial.log"
pid_file="${artifacts_dir}/qemu.pid"

require_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'error: required command not found: %s\n' "${command_name}" >&2
        exit 1
    fi
}

cleanup() {
    if [[ -n "${tail_pid:-}" ]] && kill -0 "${tail_pid}" >/dev/null 2>&1; then
        kill "${tail_pid}" >/dev/null 2>&1 || true
        wait "${tail_pid}" >/dev/null 2>&1 || true
    fi
    if [[ -n "${qemu_pid:-}" ]] && kill -0 "${qemu_pid}" >/dev/null 2>&1; then
        kill "${qemu_pid}" >/dev/null 2>&1 || true
        wait "${qemu_pid}" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT

"${script_dir}/build.sh"

mkdir -p "${artifacts_dir}"
rm -f "${pid_file}" "${serial_log}"
: > "${serial_log}"

printf 'Starting QEMU'

qemu-system-aarch64 \
  -machine "virt,accel=hvf" \
  -m "1024" \
  -smp "1" \
  -display none \
  -monitor none \
  -serial "file:${serial_log}" \
  -drive "file=${disk_image},format=qcow2,if=virtio" \
  -cdrom "${seed_iso}" \
  -nic none \
  -no-reboot &

qemu_pid="$!"
printf '%s\n' "${qemu_pid}" > "${pid_file}"

tail -n +1 -f "${serial_log}" &
tail_pid="$!"

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
