# ACEMAGIC M1A Pro+ RGB off for Linux

Turn off the RGB lighting on an **ACEMAGIC M1A Pro+ with AMD Ryzen AI Max+ 395**, immediately and automatically at each boot.

The installer adds a small Python command and a systemd service. The script identifies this model as verified; compatibility with other models or firmware versions has not been established.

## Hardware scope

This command accesses the embedded controller (EC) directly through the Linux `ec_sys` debug interface. It writes `0x00` to EC offset `0xFC`. Incorrect EC writes can affect hardware behavior. Use this only on the specified hardware after reviewing the script; it is not a generic RGB controller.

Before writing, the command checks that the current byte is one of `0x00` through `0x04`. This is a value check, **not a check of the computer's model**. It enables EC write support only when a write is needed and attempts to disable it afterward, including on errors.

## Requirements

- Linux with systemd; the installer was written for Ubuntu.
- Python 3, `modprobe`, and `install`.
- A kernel with the `ec_sys` module and the EC debug interface at `/sys/kernel/debug/ec/ec0/io`.
- Root access.

## Install

Download or clone this repository, review `install-acemagic-rgb-off.sh`, then run it from the repository directory:

```sh
sudo sh install-acemagic-rgb-off.sh
```

The installer creates:

- `/usr/local/sbin/acemagic-rgb-off`
- `/etc/systemd/system/acemagic-rgb-off.service`

It enables the service at boot and starts it immediately. Running the installer again replaces those two files and restarts the service.

## Usage

Check the service and its logs:

```sh
systemctl --no-pager --full status acemagic-rgb-off.service
journalctl -u acemagic-rgb-off.service -b --no-pager
```

Apply RGB-off again manually:

```sh
sudo systemctl restart acemagic-rgb-off.service
```

The service runs once per boot. It does not continuously monitor lighting or automatically reapply the setting after suspend/resume.

## Troubleshooting

If `ec_sys` cannot load or `/sys/kernel/debug/ec/ec0/io` is unavailable, inspect the service logs and check your kernel's support for this interface. The service requires the systemd debug filesystem mount.

If the command reports an unexpected EC lighting value, it refuses the lighting write. Do not expand the accepted values without establishing what that register means on your hardware and firmware.

The service normally shows `active (exited)` after success because it is a oneshot service with `RemainAfterExit=yes`.

## Uninstall

```sh
sudo systemctl disable --now acemagic-rgb-off.service
sudo rm -f /etc/systemd/system/acemagic-rgb-off.service
sudo rm -f /usr/local/sbin/acemagic-rgb-off
sudo systemctl daemon-reload
sudo systemctl reset-failed acemagic-rgb-off.service 2>/dev/null || true
```

Removal stops future automatic writes. It does not restore the previous lighting value, which the script does not save, or unload `ec_sys`.

## Reporting compatibility

When reporting success or a problem, include the exact PC model, BIOS/firmware version, Linux distribution, kernel version (`uname -r`), and relevant service logs. Review logs for personal information before sharing.
