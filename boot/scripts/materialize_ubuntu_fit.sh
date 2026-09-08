#!/usr/bin/env bash
set -euo pipefail

# Materialize the build-time DT change into the Ubuntu FIT selected by
# boot.scr.uimg.  This does not write to the board and is not a runtime overlay.
tree=$(cd "$(dirname "$0")/.." && pwd)
build_dir=${EDF_BUILD_DIR:-"$tree/build"}
native_bin=$(find "$build_dir" -type f -path '*/dtc-native/usr/bin/dtc' -print -quit)
dtc=${native_bin:?dtc-native not found}
fdtoverlay="${native_bin%/dtc}/fdtoverlay"
fdtput="${native_bin%/dtc}/fdtput"
dumpimage=$(find "$build_dir" -type f -name dumpimage -print -quit)
: "${dumpimage:?dumpimage not found}"
fit=${1:?known-good image.fit path required}
overlay="$tree/gem2_j10b_ubuntu_overlay.dts"
out=${2:-"$tree/artifacts/image-gem2-j10b.fit"}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

"$dumpimage" -T flat_dt -p 5 -o "$tmp/base.dtb" "$fit"
"$dtc" -@ -I dts -O dtb -o "$tmp/gem2.dtbo" "$overlay"
"$fdtoverlay" -i "$tmp/base.dtb" -o "$tmp/final.dtb" "$tmp/gem2.dtbo"
cp "$fit" "$out"
bytes=( $(od -An -v -t x1 "$tmp/final.dtb") )
"$fdtput" -t bx "$out" /images/fdt-smk-k26-revA-sck-kr-g-revB.dtb data "${bytes[@]}"
read -ra hash <<< "$(sha1sum "$tmp/final.dtb" | cut -d' ' -f1 | sed 's/../& /g')"
"$fdtput" -t bx "$out" /images/fdt-smk-k26-revA-sck-kr-g-revB.dtb/hash-1 value "${hash[@]}"
"$dumpimage" -l "$out" >/dev/null
echo "created $out"
