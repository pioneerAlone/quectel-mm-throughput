# runtime/

This directory contains artifacts meant to run **on the target device** after the patched ModemManager is installed.

## Layout

```
mmcli.sh                  # main entry point (thin orchestrator)
lib/                      # modular implementation
├── version-detect.sh     #   detects MM version via mmcli --version or D-Bus
├── mmcli-parser.sh       #   parses mmcli --output-keyvalue output
├── qmiquectel-config.sh  #   WDA / MTU / ethtool configuration primitives
└── net-setup.sh          #   IP / route / DNS bring-up
adapters/                 # per-MM-version constants
├── _loader.sh            #   dynamic loader based on detected version
├── 1.22.sh               #   MM 1.22.x constants
└── 1.24.sh               #   MM 1.24.x constants (placeholder)
udev/                     # udev templates for automatic triggering
systemd/                  # systemd unit templates
```

## Quick start

```bash
# 1. Deploy the runtime to the target device
scp -r runtime/* user@device:/tmp/qmiquectel-throughput/

# 2. Run it (must be on a device with a Quectel modem attached)
ssh user@device
sudo /tmp/qmiquectel-throughput/mmcli.sh

# 3. Dry-run mode (detect + print, no side effects)
sudo /tmp/qmiquectel-throughput/mmcli.sh --dry-run
```

## Auto-trigger via udev

To have the script run automatically when a Quectel modem is plugged in:

```bash
# On the target device:
sudo cp udev/99-qmiquectel-throughput.rules /etc/udev/rules.d/
# Edit the file to set the correct ATTR{idProduct} for your module
sudo udevadm control --reload

# Create a wrapper script that the udev rule will invoke:
sudo tee /usr/local/bin/qmiquectel-throughput-trigger.sh <<'EOF'
#!/bin/bash
sleep 5  # wait for ModemManager to enumerate the modem
exec /path/to/mmcli.sh
EOF
sudo chmod +x /usr/local/bin/qmiquectel-throughput-trigger.sh
```

## Auto-trigger via systemd

For periodic re-tuning or boot-time application:

```bash
sudo cp systemd/qmiquectel-throughput.service /etc/systemd/system/
sudo systemctl daemon-reload

# Manual start:
sudo systemctl start qmiquectel-throughput.service

# Boot-time start (optional):
sudo systemctl enable qmiquectel-throughput.service
```

## Overriding defaults

All defaults can be overridden via environment variables before invoking `mmcli.sh`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `MM_DEFAULT_APN` | `3gnet` | APN for the bearer |
| `MM_QMI_NETDEV` | `wwan0` | QMI netdev (Linux interface name) |
| `MM_QMI_DEVICE` | `/dev/cdc-wdm0` | QMI control device |
| `MM_WDA_EP_TYPE` | `hsusb` | WDA endpoint type |
| `MM_WDA_EP_IFACE` | `4` | WDA endpoint interface number |
| `MM_WDA_LINK_LAYER` | `raw-ip` | WDA link layer protocol |
| `MM_ETHTOOL_AGGR_TIME_USECS` | `1000` | TX aggregation timeout |

Example:
```bash
sudo MM_DEFAULT_APN=internet MM_QMI_NETDEV=wwan1 /tmp/qmiquectel-throughput/mmcli.sh
```

## Cross-version portability

See [../docs/runtime-portability.md](../docs/runtime-portability.md) for the full list of cross-version fragile points and how the adapter pattern isolates them.

When a new MM minor version is released:
1. Create `runtime/adapters/<major>.<minor>.sh` modeled on `1.22.sh`
2. Adjust constants to match actual output from `mmcli --output-keyvalue`
3. Add tests under `tests/` covering the new adapter
4. Update `SUPPORTED.md`