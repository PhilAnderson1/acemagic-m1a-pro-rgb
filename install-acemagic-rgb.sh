#!/bin/sh
# ACEMAGIC M1A Pro+ Ryzen AI Max+ 395 RGB control for Ubuntu.
# Usage: sudo sh install-acemagic-rgb.sh [off|auto|rainbow|breathing|color-cycle]
# No argument retains the original installer behaviour: off now and at boot.
#
# Protocol decoded from ACEMAGIC's LedControl_S3A_F3A.exe (2025-01-15):
# https://acemagic.com/pages/drivers-downloads (S3A/AMR5 lighting software)
# SHA256: 69375f6ea8d2862352e214e768c1a2d32c1b0184347a75159e8c1cbe30de93e6
# EC 0xFC: off=0, Auto=1, Rainbow=2, Breathing=3, Color Cycle=4.
# Auto is implemented but hidden in that Windows utility's interface.
# Off and restoring 0x02 have been verified on the M1A Pro+; other modes
# are decoded from the vendor program, not yet tested on that hardware.
# Other ACEMAGIC models can use different controllers or mode values.
set -eu

usage() {
    echo "Usage: sudo sh $0 [off|auto|rainbow|breathing|color-cycle]"
    echo "Install acemagic-rgb and apply the selected mode now and at boot (default: off)."
    echo "Manual use afterwards: sudo acemagic-rgb <mode>"
}

if [ "$#" -gt 1 ]; then
    usage >&2
    exit 2
fi
rgb_mode=${1-off}
case "$rgb_mode" in
    -h|--help) usage; exit 0 ;;
    off|auto|rainbow|breathing|color-cycle) ;;
    colour-cycle) rgb_mode=color-cycle ;;
    *) echo "Unknown RGB mode: $rgb_mode" >&2; usage >&2; exit 2 ;;
esac

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this installer with sudo." >&2
    exit 1
fi

for cmd in python3 modprobe systemctl; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Error: required command '$cmd' is not installed or not in PATH." >&2
        exit 1
    }
done

rgb_install_tmp=$(mktemp -d)
trap 'rm -rf -- "$rgb_install_tmp"' EXIT

cat > "$rgb_install_tmp/acemagic-rgb" <<'PYTHON'
#!/usr/bin/python3
"""RGB modes for the ACEMAGIC M1A Pro+ EC; not a generic ACEMAGIC tool.

Mode names and EC values come from LedControl_S3A_F3A.exe (2025-01-15).
Auto is hidden in the vendor GUI. Only off and restoring rainbow (0x02)
have been tested on the M1A Pro+. Always leaves ec_sys writes disabled,
including when they were enabled on entry, as the original off tool did.
"""
import argparse
import fcntl
import os
import sys
from pathlib import Path

MODES = {"off": 0, "auto": 1, "rainbow": 2, "breathing": 3, "color-cycle": 4}
EC_PATH = "/sys/kernel/debug/ec/ec0/io"
WRITE_SUPPORT = Path("/sys/module/ec_sys/parameters/write_support")
LOCK_PATH = "/run/lock/acemagic-rgb.lock"
REGISTER = 0xFC


def set_mode(mode):
    target = bytes([MODES[mode]])
    # Serialize this command's instances, including startup versus manual use.
    with open(LOCK_PATH, "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            with open(EC_PATH, "r+b", buffering=0) as ec:
                ec.seek(REGISTER)
                original = ec.read(1)
                if len(original) != 1 or original[0] not in MODES.values():
                    raise RuntimeError(
                        f"Unexpected EC lighting value {original.hex() or '(empty)'}; "
                        "no write made."
                    )
                if original != target:
                    WRITE_SUPPORT.write_text("Y\n")
                    ec.seek(REGISTER)
                    if ec.write(target) != 1:
                        raise RuntimeError("Failed to write the RGB mode.")
                    ec.seek(REGISTER)
                    if ec.read(1) != target:
                        raise RuntimeError("RGB mode read-back did not match the requested value.")
        finally:
            WRITE_SUPPORT.write_text("N\n")
    print(f"ACEMAGIC RGB: {mode}.", flush=True)


def main():
    parser = argparse.ArgumentParser(
        description="Set ACEMAGIC M1A Pro+ RGB lighting (EC register 0xFC).",
        epilog="Manual changes apply immediately. Re-run the installer to change "
        "the startup mode. Auto is implemented but hidden in the vendor GUI. "
        "EC write support is disabled on completion.",
    )
    parser.add_argument(
        "mode", choices=tuple(MODES) + ("colour-cycle",),
        help="lighting mode; colour-cycle is an alias for color-cycle",
    )
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.exit(1, "Run with sudo: sudo acemagic-rgb <mode>\n")
    if not WRITE_SUPPORT.exists() or not Path(EC_PATH).exists():
        parser.exit(1, "EC interface unavailable. Ensure debugfs is mounted and "
                    "ec_sys is loaded (sudo modprobe ec_sys write_support=0).\n")
    try:
        set_mode("color-cycle" if args.mode == "colour-cycle" else args.mode)
    except (OSError, RuntimeError) as exc:
        print(f"acemagic-rgb: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
PYTHON

# rgb_mode is validated above before interpolation into the unit.
cat > "$rgb_install_tmp/acemagic-rgb.service" <<UNIT
[Unit]
Description=Set ACEMAGIC M1A Pro+ RGB lighting
Requires=sys-kernel-debug.mount
After=sys-kernel-debug.mount systemd-modules-load.service

[Service]
Type=oneshot
ExecStartPre=/sbin/modprobe ec_sys write_support=0
ExecStart=/usr/local/sbin/acemagic-rgb $rgb_mode
ExecStopPost=/bin/sh -c 'if [ -w /sys/module/ec_sys/parameters/write_support ]; then echo N > /sys/module/ec_sys/parameters/write_support; fi'
RemainAfterExit=yes
TimeoutStartSec=15

[Install]
WantedBy=multi-user.target
UNIT

install -o root -g root -m 0755 "$rgb_install_tmp/acemagic-rgb" /usr/local/sbin/acemagic-rgb

# Upgrade the earlier installer without leaving competing startup services.
if [ -f /etc/systemd/system/acemagic-rgb-off.service ]; then
    systemctl disable --now acemagic-rgb-off.service
    rm -f /etc/systemd/system/acemagic-rgb-off.service
    rm -f /usr/local/sbin/acemagic-rgb-off
fi

install -o root -g root -m 0644 "$rgb_install_tmp/acemagic-rgb.service" /etc/systemd/system/acemagic-rgb.service
systemctl daemon-reload
systemctl enable acemagic-rgb.service
systemctl restart acemagic-rgb.service
systemctl --no-pager --full status acemagic-rgb.service
echo "Installed: RGB set to $rgb_mode now and at each boot."
echo "To change it immediately: sudo acemagic-rgb <mode>"
echo "To change the boot mode: re-run this installer with the desired mode."
