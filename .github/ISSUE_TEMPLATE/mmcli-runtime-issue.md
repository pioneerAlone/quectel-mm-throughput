---
name: mmcli.sh runtime issue
about: Report a problem running runtime/mmcli.sh on a target device
title: "[runtime] <short description>"
labels: ["runtime", "needs-triage"]
---

## What I ran

```bash
sudo ./runtime/mmcli.sh
```

## What I expected

<!-- Expected output -->

## What happened

<!-- Actual output -->

## Diagnostics

Please attach:

- `mmcli --version`
- `mmcli --output-keyvalue -L`
- `qmicli --version`
- `ls /sys/class/net/` (to see netdev names)
- `ethtool --version`
- Kernel version: `uname -r`
- Distribution: `cat /etc/os-release`

## Environment

- Target device hardware: <!-- e.g. Raspberry Pi 4, Intel NUC -->
- Quectel module: <!-- e.g. EG25-G -->
- Modem firmware: <!-- run `mmcli -m 0` and look for `firmware revision` -->
- MM version: <!-- output of `mmcli --version` -->

## Logs

If relevant, attach journal output:

```bash
journalctl -u ModemManager --since "1 hour ago" > mm.log
```