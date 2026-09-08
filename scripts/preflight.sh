#!/usr/bin/env bash
set -uo pipefail

failures=0

pass() {
    printf 'PASS: %s\n' "$1"
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

echo '== Board =='
uname -a
if [[ -r /sys/firmware/devicetree/base/model ]]; then
    tr -d '\0' </sys/firmware/devicetree/base/model
fi
echo

echo '== Boot firmware A/B =='
if bootfw_status=$(sudo xmutil bootfw_status); then
    printf '%s\n' "$bootfw_status"
    for slot in A B; do
        if grep -Eq "^Image ${slot}:[[:space:]]+Bootable[[:space:]]*$" <<<"$bootfw_status"; then
            pass "Image ${slot} is Bootable"
        else
            fail "Image ${slot} is not reported Bootable"
        fi
    done
    if grep -Eq '^Last Booted Image:[[:space:]]+Image [AB][[:space:]]*$' <<<"$bootfw_status"; then
        pass 'Last Booted Image is known'
    else
        fail 'Last Booted Image is not known'
    fi
else
    fail 'xmutil bootfw_status failed'
fi

echo '== Boot files =='
if findmnt /boot/firmware; then
    pass '/boot/firmware is mounted'
else
    fail '/boot/firmware is not mounted'
fi
lsblk -o NAME,FSTYPE,LABEL,SIZE,MOUNTPOINTS
if [[ -f /boot/firmware/image.fit ]]; then
    pass '/boot/firmware/image.fit exists'
else
    fail '/boot/firmware/image.fit does not exist'
fi
for boot_file in /boot/firmware/image.fit /boot/firmware/boot.scr.uimg; do
    if [[ -f $boot_file ]]; then
        sha256sum "$boot_file" || fail "could not hash ${boot_file}"
    fi
done

echo '== DFX manager (information only) =='
systemctl is-enabled dfx-mgr.service 2>/dev/null || true
systemctl is-active dfx-mgr.service 2>/dev/null || true

echo '== Result =='
if ((failures == 0)); then
    echo 'PASS: automatic preflight checks passed'
    echo 'MANUAL: confirm UART monitoring and recovery before deployment'
    exit 0
fi
printf 'FAIL: %d automatic preflight check(s) failed\n' "$failures" >&2
exit 1
