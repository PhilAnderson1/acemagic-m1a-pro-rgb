#!/bin/sh
# Install the RGB-off command on ACEMAGIC M1A Pro+.
# Run on that Ubuntu machine with: sudo bash install-acemagic-rgb-off.sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this installer with sudo." >&2
    exit 1
fi

command -v python3 >/dev/null
command -v modprobe >/dev/null
command -v systemctl >/dev/null

rgb_install_tmp=$(mktemp -d)
trap 'rm -rf -- "$rgb_install_tmp"' EXIT

cat > "$rgb_install_tmp/acemagic-rgb-off" <<'PYTHON'
#!/usr/bin/python3
"""Verified on ACEMAGIC M1A Pro+ Ryzen AI Max+ 395; not a generic EC tool."""
from pathlib import Path

writes = Path("/sys/module/ec_sys/parameters/write_support")
try:
    with open("/sys/kernel/debug/ec/ec0/io", "r+b", buffering=0) as ec:
        ec.seek(0xFC)
        original = ec.read(1)
        if original not in (b"\x00", b"\x01", b"\x02", b"\x03", b"\x04"):
            raise SystemExit(f"Unexpected EC lighting value {original.hex()}; no write made.")
        if original != b"\x00":
            writes.write_text("Y\n")
            ec.seek(0xFC)
            if ec.write(b"\x00") != 1:
                raise SystemExit("Failed to write RGB-off value.")
        print("ACEMAGIC RGB off.", flush=True)
finally:
    writes.write_text("N\n")
PYTHON

cat > "$rgb_install_tmp/acemagic-rgb-off.service" <<'UNIT'
[Unit]
Description=Turn off ACEMAGIC M1A Pro+ RGB lighting
Requires=sys-kernel-debug.mount
After=sys-kernel-debug.mount systemd-modules-load.service

[Service]
Type=oneshot
ExecStartPre=/sbin/modprobe ec_sys write_support=0
ExecStart=/usr/local/sbin/acemagic-rgb-off
ExecStopPost=/bin/sh -c 'if [ -w /sys/module/ec_sys/parameters/write_support ]; then echo N > /sys/module/ec_sys/parameters/write_support; fi'
RemainAfterExit=yes
TimeoutStartSec=15

[Install]
WantedBy=multi-user.target
UNIT

install -o root -g root -m 0755 "$rgb_install_tmp/acemagic-rgb-off" /usr/local/sbin/acemagic-rgb-off
install -o root -g root -m 0644 "$rgb_install_tmp/acemagic-rgb-off.service" /etc/systemd/system/acemagic-rgb-off.service
systemctl daemon-reload
systemctl enable acemagic-rgb-off.service
systemctl restart acemagic-rgb-off.service
systemctl --no-pager --full status acemagic-rgb-off.service
echo "Installed: RGB switched off now and at each boot."
