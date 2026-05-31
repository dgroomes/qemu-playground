#!/usr/bin/env bash
# Thin wrapper for convenience. See README for tutorial-style manual steps.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"${script_dir}/build.sh"
"${script_dir}/scripts/start-qemu.sh"
