# Runtime Portability Notes

Cross-version fragile points in `runtime/mmcli.sh` and its lib modules, plus how the adapter pattern isolates them.

## Why these notes exist

The runtime layer talks to **ModemManager via `mmcli`** — a CLI that wraps the D-Bus API. Across MM versions, the **CLI output format** and **DBus field names** have evolved. If we hardcoded these constants in `lib/`, every MM upgrade would require modifying core code. Instead, we isolate them in `runtime/adapters/<major>.<minor>.sh`.

## Fragile point 1: modem path regex

`mmcli -L` output contains a DBus object path. The path format has been stable since 1.10, but the **field label** in `--output-keyvalue` mode changed.

| MM version | `mmcli -L` (human) | `mmcli -L --output-keyvalue` |
|------------|--------------------|------------------------------|
| 1.18.x     | `/org/.../Modem/N (vendor) model` | `modem.N.path = /org/.../Modem/N` |
| 1.22.x     | same | same |
| 1.24.x     | same | same (verified at commit `dfa41ad`) |

**Adapter constant**: `MM_MODEM_PATH_REGEX`

## Fragile point 2: bearer property keys

`mmcli -m M -b B` field names changed across versions:

| MM version | Field for bearer interface | Field for IP address |
|------------|---------------------------|----------------------|
| 1.16       | `Bearer interface:` | `IPv4 address:` |
| 1.18+      | `interface:` (consistent) | `address:` (consistent) |

**Adapter constant**: `MM_BEARER_KEYS`

We use `mmcli --output-keyvalue` exclusively (since 1.18) so the adapter only needs to declare the **field name**, not format.

## Fragile point 3: bearer creation key/value

The `multiplex=required` syntax was introduced stable in MM 1.18. Pre-1.18 used `qmap=force-on-qmap` (Quectel-private).

| MM version | Syntax |
|------------|--------|
| < 1.18     | `--create-bearer="apn=X,qmap=force-on-qmap"` (Quectel plugin private) |
| 1.18 - 1.22 | `--create-bearer="apn=X,multiplex=required"` |
| 1.24+      | same (verified) |

**Adapter constant**: `MM_BEARER_MULTIPLEX_KEY`, `MM_BEARER_MULTIPLEX_VALUE`

If a future MM version renames this key (unlikely), update only the adapter.

## Fragile point 4: WDA endpoint defaults

`qmicli --wda-set-data-format` parameters depend on the modem's USB interface:

| Quectel module | `ep-type` | `ep-iface-number` | `link-layer-protocol` |
|----------------|-----------|--------------------|------------------------|
| EG25-G         | `hsusb`   | `4`               | `raw-ip`              |
| EG21-G         | `hsusb`   | `4`               | `raw-ip`              |
| EM060K         | `hsusb`   | `4`               | `raw-ip`              |
| RG500Q         | `hsusb`   | `4`               | `raw-ip`              |

**Adapter constants**: `MM_WDA_EP_TYPE`, `MM_WDA_EP_IFACE`, `MM_WDA_LINK_LAYER`

These are module-specific, not MM-version-specific, but they live in the adapter for consistency.

## Fragile point 5: netdev name

The QMI netdev (`wwan0`, `usb0`, etc.) is **not** an MM-version concern — it's a kernel/driver concern. But it can vary by:

- Module (some expose `wwan0`, others `usb0`)
- Driver version (older qmi_wwan drivers used `usb0`)
- udev rules in the distribution

We treat it as an **environment variable** (`MM_QMI_NETDEV`), defaulting to `wwan0`.

## Fragile point 6: mmcli version detection

`mmcli --version` output has been stable:

| MM version | Output |
|------------|--------|
| 1.20       | `mmcli 1.20.0` |
| 1.22       | `mmcli 1.22.0` |
| 1.24       | `mmcli 1.24.2` |

Fallback: `busctl get-property org.freedesktop.ModemManager1 /org/.../ModemManager1 org.freedesktop.ModemManager1 Version`.

## What the adapter pattern does NOT solve

- **mmcli binary not in PATH**: runtime error, user must install ModemManager
- **qmicli binary not in PATH**: runtime error, user must install libqmi
- **modem not detected**: `get_modem_index` returns empty, runtime halts with clear error
- **bearer already in use**: `create_or_get_bearer` should detect this via MM, but if MM returns a stale state, may need to `--delete-bearer` first

## Adding a new MM version's adapter

1. Copy `runtime/adapters/1.22.sh` to `runtime/adapters/<new-major>.<new-minor>.sh`
2. Adjust `MM_ADAPTER_VERSION_PATTERN` to match
3. Run mmcli on a system with that MM version and capture `--output-keyvalue -L` output
4. Adjust `MM_BEARER_KEYS` if field names changed
5. Test by sourcing the adapter from a debug shell:
   ```bash
   $ source runtime/adapters/1.24.sh
   $ echo $MM_BEARER_KEYS
   connected interface address prefix gateway dns mtu
   ```
6. Run `bats tests/mmcli-parser.bats` (which currently mocks mmcli for 1.22 fixtures — extend fixtures for new version)