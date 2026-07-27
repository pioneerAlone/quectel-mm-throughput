#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# version-detect.sh — detect ModemManager version at runtime.
#
# Source this file from mmcli.sh. Exports:
#   detect_mm_version  — echoes the detected MM version (e.g. "1.22.0")
#
# Detection strategy:
#   1. Try `mmcli --version` and parse its output.
#   2. Fall back to querying D-Bus for org.freedesktop.ModemManager1's version property.
#
# Supported MM version patterns:
#   - mmcli 1.22.0
#   - mmcli 1.24.2
#   - ModemManager 1.22.0-2 (Debian-style)
#
# Cross-version notes: mmcli --version output format has been stable across 1.20–1.24.

set -euo pipefail

# Patterns for the major known MM version families.
declare -a MM_VERSION_PATTERNS=(
    '1\.22\.'
    '1\.24\.'
    '1\.20\.'
    '1\.18\.'
)

detect_mm_version() {
    local raw=""

    # Path 1: mmcli --version
    if command -v mmcli >/dev/null 2>&1; then
        raw="$(mmcli --version 2>&1 || true)"
    fi

    # Path 2: D-Bus introspection of ModemManager daemon
    if [[ -z "${raw}" ]] && command -v busctl >/dev/null 2>&1; then
        raw="$(busctl get-property org.freedesktop.ModemManager1 \
            /org/freedesktop/ModemManager1 org.freedesktop.ModemManager1 \
            Version 2>/dev/null || true)"
        # busctl returns quoted "1.22.0"; strip quotes.
        raw="${raw%\"}"
        raw="${raw#\"}"
    fi

    if [[ -z "${raw}" ]]; then
        echo "mmcli not found and D-Bus query failed" >&2
        return 1
    fi

    # Extract the longest X.Y.Z version-like substring.
    local version
    version="$(printf '%s\n' "${raw}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
    if [[ -z "${version}" ]]; then
        echo "could not parse version from: ${raw}" >&2
        return 2
    fi

    # Validate against known families; warn if unknown but still echo.
    local known=0
    for pat in "${MM_VERSION_PATTERNS[@]}"; do
        if [[ "${version}" =~ ^${pat} ]]; then
            known=1
            break
        fi
    done
    if [[ "${known}" -eq 0 ]]; then
        echo "WARNING: MM version ${version} is not in the known families list" >&2
        echo "WARNING: please add an adapter at runtime/adapters/${version%.*}.sh" >&2
    fi

    echo "${version}"
}