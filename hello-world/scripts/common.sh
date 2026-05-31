#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)"
artifacts_dir="${script_dir}/artifacts"
guest_share_dir="${script_dir}/guest-share"

disk_image="${artifacts_dir}/hello.qcow2"
seed_iso="${artifacts_dir}/seed.iso"
serial_log="${artifacts_dir}/serial.log"
efi_vars="${artifacts_dir}/edk2-aarch64-vars.fd"

require_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'error: required command not found: %s\n' "${command_name}" >&2
        exit 1
    fi
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
