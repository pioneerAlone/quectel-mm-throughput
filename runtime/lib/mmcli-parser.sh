#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# mmcli-parser.sh — parse mmcli output for the qmiquectel throughput flow.
#
# Source this file from mmcli.sh. All exported functions rely on adapter
# constants from runtime/adapters/<version>.sh:
#   - MM_MODEM_PATH_REGEX
#   - MM_BEARER_KEYS
#   - MM_BEARER_MULTIPLEX_KEY / MM_BEARER_MULTIPLEX_VALUE
#
# All parsing uses `mmcli --output-keyvalue` (stable across 1.18+) so the
# adapter only needs to declare field names, not format conventions.

set -euo pipefail

# ---------------------------------------------------------------------------
# Modem index
# ---------------------------------------------------------------------------

get_modem_index() {
    local raw
    raw="$(mmcli --output-keyvalue -L 2>&1 || true)"

    if [[ -z "${raw}" ]]; then
        # Fall back to human-readable output and grep for the path.
        raw="$(mmcli -L 2>&1 || true)"
        printf '%s\n' "${raw}" | \
            grep -oP "(?<=${MM_MODEM_PATH_REGEX})[0-9]+" | \
            head -n1
        return $?
    fi

    # keyvalue output: "modem.0.path = /org/freedesktop/ModemManager1/Modem/0"
    printf '%s\n' "${raw}" | \
        awk -F' *= *' -v pat="${MM_MODEM_PATH_REGEX}" \
            '$1 ~ /modem\.[0-9]+\.path/ && $2 ~ pat { split($2,a,"/"); print a[length(a)]; exit }'
}

# ---------------------------------------------------------------------------
# Bearer management
# ---------------------------------------------------------------------------

create_or_get_bearer() {
    local modem="$1"
    local apn="${2:-${MM_DEFAULT_APN:-3gnet}}"

    # Reuse an existing bearer if one is already attached to the modem.
    local existing
    existing="$(mmcli --output-keyvalue -m "${modem}" -b 2>&1 | \
        awk -F' *= *' '$1 ~ /^bearer\.[0-9]+\.path/ { print $2; exit }' || true)"

    if [[ -n "${existing}" ]]; then
        echo "${existing}"
        return 0
    fi

    # No bearer present: create one with QMAP multiplex required.
    local mux_key="${MM_BEARER_MULTIPLEX_KEY}"
    local mux_val="${MM_BEARER_MULTIPLEX_VALUE}"
    mmcli -m "${modem}" \
        --create-bearer="apn=${apn},${mux_key}=${mux_val},ip-type=ipv4" \
        >/dev/null

    # Re-read to get the new bearer path.
    mmcli --output-keyvalue -m "${modem}" -b 2>&1 | \
        awk -F' *= *' '$1 ~ /^bearer\.[0-9]+\.path/ { print $2; exit }'
}

get_bearer_field() {
    local bearer_path="$1"
    local field="$2"
    # bearer_path looks like /org/freedesktop/ModemManager1/Bearer/N
    local bnum="${bearer_path##*/}"

    mmcli --output-keyvalue -m 0 -b "/org/freedesktop/ModemManager1/Bearer/${bnum}" 2>&1 | \
        awk -F' *= *' -v f="${field}" -v n="${bnum}" \
            '$1 == ("bearer." n "." f) { print $2; exit }'
}

# ---------------------------------------------------------------------------
# WDA AGG params (read back after apply_wda_format)
# ---------------------------------------------------------------------------

read_wda_agg_params() {
    # globals set by this function:
    #   dl_agg_size, ul_agg_size, ul_agg_datagrams
    local raw
    raw="$(qmicli -p -d "${MM_QMI_NETDEV:-/dev/cdc-wdm0}" \
              --wda-get-data-format 2>&1 || true)"

    get_wda_field() {
        printf '%s\n' "$1" | awk -v k="$2" -F"'" '
            $0 ~ k ":" { print $2; exit }
        '
    }

    dl_agg_size="$(get_wda_field "${raw}" 'Downlink data aggregation max size')"
    ul_agg_size="$(get_wda_field "${raw}" 'Uplink data aggregation max size')"
    ul_agg_datagrams="$(get_wda_field "${raw}" 'Uplink data aggregation max datagrams')"

    export dl_agg_size ul_agg_size ul_agg_datagrams

    if [[ -z "${dl_agg_size}" || -z "${ul_agg_size}" || -z "${ul_agg_datagrams}" ]]; then
        echo "read_wda_agg_params: incomplete output" >&2
        return 1
    fi
}