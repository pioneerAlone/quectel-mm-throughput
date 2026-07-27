# Parameter Rationale

Why these specific values for UL Data Aggregation?

| Parameter | Value | Source |
|-----------|-------|--------|
| `uplink_data_aggregation_max_size` | 4096 bytes | Quectel EG25/EG21 datasheet recommendation + empirical |
| `uplink_data_aggregation_max_datagrams` | 11 | Empirical — maximizes throughput without exceeding modem buffer |
| `ethtool tx-aggr-time-usecs` | 1000 µs (1 ms) | Matches WDA aggregation window on Quectel modems |

## Background

Quectel modems that use the QMI protocol support two layers of uplink aggregation:

1. **Modem-internal (WDA) aggregation**: Inside the modem, multiple IP packets destined for the cellular uplink are bundled into larger QMI frames to reduce per-packet protocol overhead.
2. **Host-side (ethtool) aggregation**: On the host, after QMAP demultiplexing, the qmapmux* sub-interface can be told to coalesce packets before passing them to userspace.

Both layers must be tuned for the **same maximum frame size**, otherwise the lower layer's max becomes the bottleneck.

## Why 4096 bytes

- **Modem limit**: Quectel EG25/EG21 datasheet states the modem supports up to 32768 bytes for downlink aggregation, but uplink is capped lower. Empirically, 4096 is the highest stable value across the EG25 family.
- **MTU alignment**: A 4096-byte UL AGG size requires the host-side `wwan0` MTU to be at least 4096, or larger packets get dropped. We set `wwan0` MTU accordingly (see `configure_mtu` in `runtime/lib/qmiquectel-config.sh`).
- **Standardized**: 4096 matches Quectel's `AT+QMAP="DLAGGR"` recommendation for several modules.

## Why 11 datagrams

- Quectel firmware internally tunes `tx-aggr-max-frames` against the modem's uplink buffer. Empirically:
  - 1-7 datagrams: noticeable packet loss under load
  - 8-11 datagrams: stable, maximum throughput
  - 12+ datagrams: diminishing returns, increased latency
- 11 is the "knee" where latency stops increasing linearly with throughput.

## Why 1000 µs aggregation time

- The WDA aggregation completes either when:
  - the buffer is full (`max-size` bytes), OR
  - `max-datagrams` packets accumulate, OR
  - `tx-aggr-time-usecs` microseconds elapse
- 1000 µs (1 ms) matches the typical cellular scheduling slot. Below 500 µs, the aggregation rarely completes; above 2000 µs, latency suffers.

## Empirical evidence

The values were originally measured against `materials/提升ModemManager 数传吞吐量方案.pptx` (slide deck capturing throughput benchmarks with these settings).

To re-derive empirically:
```bash
# On a target device with EG25/EG21:
# 1. Baseline (no aggregation):
mmcli -m 0 --create-bearer="apn=3gnet"
iperf3 -c <server> -t 30

# 2. With our patch + mmcli.sh:
./runtime/mmcli.sh
iperf3 -c <server> -t 30
```

Expected delta: ~2-3× uplink throughput on saturated LTE links. Exact numbers depend on the cell tower, signal conditions, and module variant.

## What we did NOT choose

- **32 KB aggregation size**: would require kernel/driver support that not all wwan drivers provide
- **High datagram counts (32+)**: triggers modem-side buffer overflows on EG21
- **Long aggregation times (>2 ms)**: violates typical latency budgets for interactive traffic