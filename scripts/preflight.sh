#!/usr/bin/env bash
set -u

echo '== Board =='
uname -a
tr -d '\0' </sys/firmware/devicetree/base/model 2>/dev/null || true
echo
echo '== Boot firmware A/B =='
sudo xmutil bootfw_status
echo '== Boot files =='
findmnt /boot/firmware
lsblk -o NAME,FSTYPE,LABEL,SIZE,MOUNTPOINTS
sha256sum /boot/firmware/image.fit /boot/firmware/boot.scr.uimg
echo '== DFX manager =='
systemctl is-enabled dfx-mgr.service 2>/dev/null || true
systemctl is-active dfx-mgr.service 2>/dev/null || true
