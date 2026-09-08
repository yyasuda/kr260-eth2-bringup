#!/usr/bin/env bash
set -euo pipefail

tree=$(cd "$(dirname "$0")/../.." && pwd)
xsa=${1:-"$tree/hardware/artifacts/gem2_j10b.xsa"}
out=${2:-"$tree/hardware/artifacts/sdt-gem2-j10b.tar.gz"}

command -v sdtgen >/dev/null || {
    echo 'sdtgen not found; source the Vivado/Vitis 2026.1 settings first' >&2
    exit 1
}
[[ -f $xsa ]] || {
    printf 'XSA not found: %s\n' "$xsa" >&2
    exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sdt_dir="$work/sdt-gem2-j10b"

printf '%s\n' \
    "set_dt_param -dir $sdt_dir" \
    "set_dt_param -xsa $xsa" \
    'set_dt_param -board_dts zynqmp-smk-k26-reva' \
    'generate_sdt' \
    'exit' \
    | sdtgen

[[ -f $sdt_dir/system-top.dts ]] || {
    echo 'sdtgen did not create system-top.dts' >&2
    exit 1
}
mkdir -p "$(dirname "$out")"
tar -C "$work" -czf "$out" sdt-gem2-j10b
printf 'created %s\n' "$out"
sha256sum "$out"
