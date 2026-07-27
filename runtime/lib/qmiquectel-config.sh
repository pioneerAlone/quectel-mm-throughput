#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# qmiquectel-config.sh — Quectel + QMI WDA configuration primitives.
#
# Source this file from mmcli.sh. These functions rely on:
#   - The ModemManager build was patched (see patches/) so MM internally sends
#     UL AGG parameters when calling qmi_client_wda_set_data_format().
#   - read_wda_agg_params() from mmcli-parser.sh has populated the globals
#     dl_agg_size, ul_agg_size, ul_agg_datagrams.

set -euo pipefail

QMI_DEVICE_DEFAULT="/dev/cdc-wdm0"
QMI_DEVICE="${MM_QMI_DEVICE:-${QMI_DEVICE_DEFAULT}}"

enable_qmi_passthrough() {
    local netdev="$1"
    local pt_path="/sys/class/net/${netdev}/qmi/pass_through"

    if [[ ! -e "${pt_path}" ]]; then
        echo "enable_qmi_passthrough: ${pt_path} not found (is ${netdev} a QMI device?)" >&2
        return 1
    fi

    echo Y > "${pt_path}"
}

apply_wda_format() {
    local modem="$1"
    local ep_type="${MM_WDA_EP_TYPE:-hsusb}"
    local ep_iface="${MM_WDA_EP_IFACE:-4}"
    local link_layer="${MM_WDA_LINK_LAYER:-raw-ip}"

    # The patched MM will set UL AGG defaults internally based on the patch.
    # We only need to specify the endpoint type, interface, and link layer.
    qmicli -p -d "${QMI_DEVICE}" \
        --wda-set-data-format="ep-type=${ep_type},ep-iface-number=${ep_iface},link-layer-protocol=${link_layer}" \
        >/dev/null
}

configure_mtu() {
    local netdev="$1"
    local target_mtu="$2"
    local current_mtu

    current_mtu="$(ip link show "${netdev}" | grep -oP 'mtu \K\d+')"
    if [[ "${current_mtu}" -ge "${target_mtu}" ]]; then
        echo "configure_mtu: ${netdev} already at ${current_mtu} (>= ${target_mtu})" >&2
        return 0
    fi

    ip link set "${netdev}" down
    if ! ip link set "${netdev}" up mtu "${target_mtu}"; then
        # Some drivers require MTU = agg_size + 8
        local fallback=$((target_mtu + 8))
        ip link set "${netdev}" up mtu "${fallback}"
    fi

    local after_mtu
    after_mtu="$(ip link show "${netdev}" | grep -oP 'mtu \K\d+')"
    if [[ "${after_mtu}" -lt "${target_mtu}" ]]; then
        echo "configure_mtu: failed, current=${after_mtu} target=${target_mtu}" >&2
        return 1
    fi
    echo "configure_mtu: ${netdev} set to ${after_mtu}" >&2
}

configure_ethtool_agg() {
    local agg_bytes="$1"
    local agg_frames="$2"
    local qmap_iface

    qmap_iface="$(get_qmapmux_interface)"
    if [[ -z "${qmap_iface}" ]]; then
        echo "configure_ethtool_agg: no qmapmux interface found, skipping" >&2
        return 0
    fi

    ethtool -C "${qmap_iface}" \
        tx-aggr-max-bytes "${agg_bytes}" \
        tx-aggr-max-frames "${agg_frames}" \
        tx-aggr-time-usecs "${MM_ETHTOOL_AGGR_TIME_USECS:-1000}" >/dev/null

    # Verify
    ethtool -c "${qmap_iface}" | \
        grep -E "tx-aggr-max-bytes|tx-aggr-max-frames|tx-aggr-time-usecs" >&2
}

get_qmapmux_interface() {
    # Look for qmapmux* in `ip -o link show` output.
    ip -o link show | \
        awk -F': ' '{print $2}' | \
        grep -oE 'qmapmux[0-9a-z_-]*' | \
        head -n1
}