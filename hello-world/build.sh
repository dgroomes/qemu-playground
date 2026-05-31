#!/usr/bin/env bash
# Build the artifacts for the QEMU Hello World demo:
#
#   1. Download the Ubuntu server cloud image once.
#   2. Generate a cloud-init NoCloud seed ISO with macOS hdiutil.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
artifacts_dir="${script_dir}/artifacts"
cloud_init_dir="${script_dir}/cloud-init"

# base_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
# TODO check the hash: 5e091e27d60116efbb0c743b8dd5cb2d15618e414ef04db0817ed43c8e2d7c7b
base_url="https://cloud-images.ubuntu.com/resolute/20260520/resolute-server-cloudimg-arm64.img"

base_image="${artifacts_dir}/resolute-server-cloudimg-arm64.qcow2"
seed_iso="${artifacts_dir}/seed.iso"

require_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'error: required command not found: %s\n' "${command_name}" >&2
        exit 1
    fi
}

build_seed_iso() {
    require_command hdiutil

    local staging
    staging="$(mktemp -d "${TMPDIR:-/tmp}/qemu-hello-seed.XXXXXX")"

    cp "${cloud_init_dir}/user-data" "${staging}/user-data"
    cp "${cloud_init_dir}/meta-data" "${staging}/meta-data"

    rm -f "${seed_iso}"
    hdiutil makehybrid -quiet -iso -joliet -default-volume-name cidata \
        -o "${seed_iso}" "${staging}"
    rm -rf "${staging}"
}

require_command curl

mkdir -p "${artifacts_dir}"

if [[ ! -f "${base_image}" ]]; then
    printf 'Downloading %s\n' "${base_url}"
    curl --fail --location --output "${base_image}.partial" "${base_url}"
    mv "${base_image}.partial" "${base_image}"
fi

printf 'Generating cloud-init seed %s\n' "${seed_iso}"
build_seed_iso

printf 'Built %s\n' "${seed_iso}"
