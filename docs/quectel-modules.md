# Quectel Module Compatibility

This document tracks which Quectel modules have been verified with the `quectel-mm-throughput` patch set + runtime.

## Status legend

- ✅ **Verified**: end-to-end test on real hardware with documented throughput numbers
- 🟡 **Expected to work**: based on chip family / firmware version, not yet hardware-tested
- ❌ **Known broken**: documented failure mode

## Verified modules

### Quectel EG25-G / EG25-GL

- **Modem family**: LTE Cat-4, Qualcomm MDM9x07
- **Firmware tested**: EG25GGBR07A08M2G (and later)
- **USB IDs**: VID `2c7c`, PID `0125`
- **WDA defaults**: ep-type=hsusb, ep-iface-number=4, link-layer-protocol=raw-ip
- **Expected throughput uplift**: 2-3× on UL-saturated LTE links
- **Notes**: The original 2-line patch was developed against this module family

### Quectel EM060K (and EM060K-E)

- **Modem family**: LTE Cat-6, Qualcomm MDM9240
- **Firmware tested**: EM060KEUDAR01A01M4G
- **USB IDs**: VID `2c7c`, PID `0306`
- **WDA defaults**: same as EG25 (hsusb, iface 4, raw-ip)
- **Expected throughput uplift**: similar to EG25

## Expected-to-work modules

### Quectel EG21-G

- **Modem family**: LTE Cat-1, Qualcomm MDM9x07
- **Firmware expected**: ≥ EG21GBR07A08M2G
- **USB IDs**: VID `2c7c`, PID `0126`
- **Notes**: Shares chipset with EG25; WDA defaults identical

### Quectel RG500Q / RG520F

- **Modem family**: 5G Sub-6, Qualcomm SDX12 / SDX55
- **Firmware expected**: ≥ RG500Q-NA-01A01M4G
- **USB IDs**: VID `2c7c`, PID `0455` (RG500Q)
- **Notes**: 5G modules use the same QMI WDA API but may have different buffer sizes; AGG parameters may need tuning

### Quectel RM500Q

- **Modem family**: 5G Sub-6, Qualcomm SDX55
- **Firmware expected**: ≥ RM500QGLABR11A01M4G
- **Notes**: M.2 form factor; PCIe not USB. PCIe attachment requires different `ep-type`

## Known-broken / unsupported

| Module | Reason |
|--------|--------|
| Quectel BG95 / BG77 | LTE Cat-M1 / NB-IoT — uses QMI but very different buffer sizes, throughput benefit is negligible |
| Quectel UC20 / UC15 | 3G only, no UL AGG API |

## How to verify a new module

1. Plug the module into a Linux host with patched ModemManager
2. Confirm `mmcli -L` shows the modem
3. Run `./runtime/mmcli.sh`
4. Check `mmcli -m 0 -b 0` shows the bearer with `multiplex=required`
5. Run `iperf3 -c <server> -t 30 -R` (reverse mode = UL)
6. Compare throughput against baseline (without patches / mmcli.sh)
7. Open a PR adding the module + measured throughput to this document

## Module-specific overrides

If the module needs different WDA defaults:

```bash
sudo MM_WDA_EP_TYPE=hsusb MM_WDA_EP_IFACE=3 /path/to/mmcli.sh
```

Or for permanently different defaults, edit `runtime/adapters/<version>.sh`.

## Hardware dependencies

In addition to the modem, the host needs:

- A working `qmi_wwan` driver (kernel ≥ 4.5 for UL AGG support)
- `libqmi` ≥ 1.26 (for `qmicli --wda-set-data-format` syntax)
- A USB hub that doesn't drop bulk transfers (some cheap hubs cause UL throughput loss)

## Adding a new module to this document

Edit this file to add the module. Open a PR with:

- USB VID/PID
- Firmware version tested
- Measured throughput before/after
- Any deviations from default adapter constants