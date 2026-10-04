# ACEMAGIC M1A Pro+ RGB control for Linux

Select an RGB lighting mode on an **ACEMAGIC M1A Pro+ with AMD Ryzen AI Max+ 395**, immediately and automatically at each boot.

`install-acemagic-rgb.sh` installs a Python command, `acemagic-rgb`, and a systemd service. Use the command to change the lights immediately and the installer to choose the startup mode.

## Supported modes

| Mode | EC value |
| --- | --- |
| `off` | `0x00` |
| `auto` | `0x01` |
| `rainbow` | `0x02` |
| `breathing` | `0x03` |
| `color-cycle` | `0x04` |

`colour-cycle` is also accepted as an alias for `color-cycle`. The default installer mode is `off`.

The mode names and values were decoded from ACEMAGIC's `LedControl_S3A_F3A.exe` (2025-01-15), distributed as S3A/AMR5 lighting software.

## Requirements

- Linux with systemd; the installer was written for Ubuntu.
- Python 3, `modprobe`, and `install`.
- A kernel with the `ec_sys` module and the EC debug interface at `/sys/kernel/debug/ec/ec0/io`.
- The systemd debug filesystem mount and a writable `/run/lock` directory for the command's lock file.
- Root access.

## Install or change the startup mode

Download or clone this repository, review `install-acemagic-rgb.sh`, then run it from the repository directory. For example, select rainbow now and at every boot:

```sh
sudo sh install-acemagic-rgb.sh rainbow
```

Use any mode from the table above. To turn the lights off now and at boot, omit the argument or specify `off`:

```sh
sudo sh install-acemagic-rgb.sh
```

The installer creates:

- `/usr/local/sbin/acemagic-rgb`
- `/etc/systemd/system/acemagic-rgb.service`

It enables the service at boot and restarts it immediately to apply the selected mode. Re-run the installer with a different mode to change the startup setting; it replaces the installed command and service.

## Change the lights immediately

After installation, run the command with the desired mode:

```sh
sudo acemagic-rgb off
sudo acemagic-rgb auto
sudo acemagic-rgb rainbow
sudo acemagic-rgb breathing
sudo acemagic-rgb color-cycle
```

Each command applies its mode immediately. Manual changes do not update the startup mode stored in the service. To reapply the configured startup mode:

```sh
sudo systemctl restart acemagic-rgb.service
```

The service runs once per boot. It does not continuously monitor lighting or automatically reapply the mode after suspend/resume.

Show command or installer help:

```sh
acemagic-rgb --help
sh install-acemagic-rgb.sh --help
```

## Status and troubleshooting

```sh
systemctl --no-pager --full status acemagic-rgb.service
journalctl -u acemagic-rgb.service -b --no-pager
```

The service normally shows `active (exited)` after success because it is a oneshot service with `RemainAfterExit=yes`.

If the command reports that the EC interface is unavailable, check that debugfs is mounted and load the module with writes disabled:

```sh
sudo modprobe ec_sys write_support=0
```

The manual command requires the EC interface to be available; the service loads the module before applying its configured mode. If `ec_sys` cannot load or `/sys/kernel/debug/ec/ec0/io` remains unavailable, inspect the service logs and check your kernel's support for this interface.

An unexpected EC lighting value causes the command to refuse the lighting write. Do not expand the accepted values without establishing what that register means on your hardware and firmware. A read-back mismatch means the value read after writing did not match the requested mode; inspect the logs before trying again.

## Uninstall

```sh
sudo systemctl disable --now acemagic-rgb.service
sudo rm -f /etc/systemd/system/acemagic-rgb.service
sudo rm -f /usr/local/sbin/acemagic-rgb
sudo systemctl daemon-reload
sudo systemctl reset-failed acemagic-rgb.service 2>/dev/null || true
```

Removal stops future automatic mode changes. It does not restore the previous lighting value, which the command does not save, or unload `ec_sys`. If you want a particular mode left active, set it before uninstalling.

## Reporting compatibility

When reporting success or a problem, include the exact PC model, BIOS/firmware version, Linux distribution, kernel version (`uname -r`), modes tried, and relevant service logs. Review logs for personal information before sharing.

## License

This project is licensed under the [MIT License](LICENSE).
