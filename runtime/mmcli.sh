#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# mmcli.sh — main entry point for Quectel + ModemManager throughput tuning.
#
# This script MUST be sourced by the actual logic; do NOT call lib/* directly.
# Use:
#   ./runtime/mmcli.sh            # default: auto-detect modem, run full flow
#   ./runtime/mmcli.sh --dry-run  # print actions without executing
#
# Workflow:
#   1. detect ModemManager version
#   2. load MM version adapter (constants only)
#   3. load lib modules (parser / config / net)
#   4. find modem, enable QMI passthrough
#   5. create or reuse QMAP bearer
#   6. apply WDA data format (rely on patched MM for UL AGG defaults)
#   7. adjust MTU on wwan0 to match DL AGG size
#   8. configure ethtool on qmapmux* interface
#   9. configure IP / route / DNS
#
# See docs/runtime-portability.md for cross-version fragility notes.

set -euo pipefail

# Resolve script directory regardless of how it was invoked.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
fi

log() {
    echo "[mmcli.sh] $*" >&2
}

die() {
    log "ERROR: $*"
    exit 1
}

# Load lib modules in order.
# shellcheck source=lib/version-detect.sh
source "${SCRIPT_DIR}/lib/version-detect.sh"
# shellcheck source=lib/mmcli-parser.sh
source "${SCRIPT_DIR}/lib/mmcli-parser.sh"
# shellcheck source=lib/qmiquectel-config.sh
source "${SCRIPT_DIR}/lib/qmiquectel-config.sh"
# shellcheck source=lib/net-setup.sh
source "${SCRIPT_DIR}/lib/net-setup.sh"

# Detect MM version, then load the matching adapter.
mm_version="$(detect_mm_version)" || die "ModemManager not detected"
log "Detected ModemManager version: ${mm_version}"

# shellcheck source=adapters/_loader.sh
source "${SCRIPT_DIR}/adapters/_loader.sh"
load_adapter "${mm_version}" || die "no adapter for MM ${mm_version}"
log "Loaded adapter: ${mm_version}"

# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------

# 1. Find modem index.
m="$(get_modem_index)" || die "no modem found via mmcli -L"
log "Modem index: ${m}"

# 2. Enable QMI passthrough on the QMI netdev.
qmi_netdev="${MM_QMI_NETDEV:-wwan0}"
enable_qmi_passthrough "${qmi_netdev}" || die "failed to enable QMI passthrough on ${qmi_netdev}"

# 3. Create or reuse a QMAP-multiplexed bearer.
apn="${MM_DEFAULT_APN:-3gnet}"
bearer_path="$(create_or_get_bearer "${m}" "${apn}")" \
    || die "failed to create/reuse bearer"
log "Bearer path: ${bearer_path}"

# 4. Apply WDA data format (this is where the patched MM's UL AGG defaults kick in).
apply_wda_format "${m}" || die "WDA data format negotiation failed"

# 5. Read back the AGG parameters the modem accepted.
read_wda_agg_params
log "DL agg size: ${dl_agg_size}, UL agg size: ${ul_agg_size}, UL agg datagrams: ${ul_agg_datagrams}"

# 6. Adjust wwan0 MTU to be at least DL AGG size.
configure_mtu "${qmi_netdev}" "${dl_agg_size}" || die "failed to set MTU on ${qmi_netdev}"

# 7. Configure ethtool on the qmapmux* interface (NOT wwan0).
configure_ethtool_agg "${ul_agg_size}" "${ul_agg_datagrams}"

# 8. Read bearer networking details and apply.
configure_ip_route_dns "${bearer_path}"

log "Done. Modem ${m} on bearer ${bearer_path} is configured for high throughput."

if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "(dry-run: no commands were actually executed beyond detection/parsing)"
fi