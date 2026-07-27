---
name: New ModemManager version not working
about: Report that patches don't apply or runtime fails for a specific MM version
title: "[patch] MM <version> not working"
labels: ["upstream-compat", "needs-triage"]
---

## ModemManager version

<!-- e.g. 1.22.0 -->

## Quectel module

<!-- e.g. EG25-G firmware EG25GGBR07A08M2G -->

## What I did

<!-- Steps you took -->

## What I expected

<!-- What should have happened -->

## What happened

<!-- Actual output, error messages, logs -->

## Diagnostics

Run these on the target device and paste the output:

```bash
mmcli --version
mmcli --output-keyvalue -L
mmcli --output-keyvalue -m 0 -b 0
lsusb | grep -i quectel
uname -a
```

## Checklist

- [ ] I have read `docs/anchor-strategy.md`
- [ ] I have checked `SUPPORTED.md` for the version's status
- [ ] I have run `scripts/verify-anchor.sh --upstream`