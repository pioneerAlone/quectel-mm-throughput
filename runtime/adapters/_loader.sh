#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# _loader.sh — load the ModemManager version-specific adapter.
#
# Source this file from mmcli.sh. Then call:
#   load_adapter <mm_version>      # e.g. load_adapter "1.22.0"
#
# This will source the adapter file at:
#   ${SCRIPT_DIR}/adapters/<major>.<minor>.sh
# which exports MM_MODEM_PATH_REGEX, MM_BEARER_KEYS, etc.
#
# Why a loader? Each MM minor version has slightly different output format
# constants. Isolating them here means main flow code never hardcodes a
# version assumption.

set -euo pipefail

SCRIPT_DIR_FOR_ADAPTER="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

load_adapter() {
    local version="$1"
    local major minor adapter_path

    major="${version%%.*}"
    rest="${version#*.}"
    minor="${rest%%.*}"

    adapter_path="${SCRIPT_DIR_FOR_ADAPTER}/${major}.${minor}.sh"

    if [[ ! -f "${adapter_path}" ]]; then
        echo "load_adapter: no adapter at ${adapter_path}" >&2
        echo "load_adapter: create one or use a placeholder" >&2
        return 1
    fi

    # shellcheck source=adapters/${major}.${minor}.sh
    source "${adapter_path}"
}