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

echo '== DFX manager =='
dfx_enabled=$(systemctl is-enabled dfx-mgr.service 2>/dev/null || true)
dfx_active=$(systemctl is-active dfx-mgr.service 2>/dev/null || true)
printf 'enabled: %s\nactive: %s\n' "${dfx_enabled:-unknown}" "${dfx_active:-unknown}"
[[ $dfx_enabled == masked ]] && pass 'dfx-mgr.service is masked' || fail 'dfx-mgr.service is not masked'
[[ $dfx_active == inactive ]] && pass 'dfx-mgr.service is inactive' || fail 'dfx-mgr.service is not inactive'

echo '== Boot firmware A/B (information only) =='
sudo xmutil bootfw_status || fail 'xmutil bootfw_status failed'

echo '== eth2 =='
if ip_output=$(ip -details link show eth2 2>&1); then
    printf '%s\n' "$ip_output"
    if grep -Eq '^[0-9]+: eth2: <[^>]*LOWER_UP[^>]*>' <<<"$ip_output"; then
        pass 'eth2 has LOWER_UP'
    else
        fail 'eth2 does not have LOWER_UP'
    fi
else
    printf '%s\n' "$ip_output" >&2
    fail 'eth2 does not exist or could not be queried'
fi

ethtool -i eth2 || fail 'ethtool driver query failed'
if ethtool_output=$(ethtool eth2 2>&1); then
    printf '%s\n' "$ethtool_output"
    grep -Eq '^[[:space:]]*Speed:[[:space:]]*1000Mb/s[[:space:]]*$' <<<"$ethtool_output" \
        && pass 'eth2 speed is 1000Mb/s' || fail 'eth2 speed is not 1000Mb/s'
    grep -Eq '^[[:space:]]*Duplex:[[:space:]]*Full[[:space:]]*$' <<<"$ethtool_output" \
        && pass 'eth2 duplex is Full' || fail 'eth2 duplex is not Full'
    grep -Eq '^[[:space:]]*PHYAD:[[:space:]]*2[[:space:]]*$' <<<"$ethtool_output" \
        && pass 'eth2 PHYAD is 2' || fail 'eth2 PHYAD is not 2'
    grep -Eq '^[[:space:]]*Link detected:[[:space:]]*yes[[:space:]]*$' <<<"$ethtool_output" \
        && pass 'eth2 link is detected' || fail 'eth2 link is not detected'
else
    printf '%s\n' "$ethtool_output" >&2
    fail 'ethtool eth2 failed'
fi

echo '== macb / PHY kernel messages (information only) =='
journalctl -k -b --no-pager 2>/dev/null \
    | grep -Ei 'ff0d0000|eth2|macb|dp83867|gmii' \
    | tail -n 100 || true

echo '== Result =='
if ((failures == 0)); then
    echo 'PASS: automatic eth2 checks passed'
    echo 'MANUAL: confirm link LEDs and cable insertion/removal tracking on both ends'
    exit 0
fi
printf 'FAIL: %d automatic eth2 check(s) failed\n' "$failures" >&2
exit 1
