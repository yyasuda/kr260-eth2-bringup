#!/usr/bin/env bash
set -u

# Reference information only; evaluate it against docs/REPRODUCE.ja.md.
echo '== DFX manager =='
systemctl is-enabled dfx-mgr.service 2>/dev/null || true
systemctl is-active dfx-mgr.service 2>/dev/null || true
echo '== Boot firmware A/B =='
sudo xmutil bootfw_status
echo '== eth2 =='
ip -details link show eth2
readlink -f /sys/class/net/eth2/device
ethtool -i eth2
ethtool eth2
echo '== macb / PHY kernel messages =='
journalctl -k -b --no-pager | grep -Ei 'ff0d0000|eth2|macb|dp83867|gmii' | tail -n 100
