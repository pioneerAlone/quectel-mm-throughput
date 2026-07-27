#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# verify-anchor.sh — ensure the QUECTEL_THROUGHPUT_ANCHOR string exists in every
# 01-anchor.patch and (for "tested" versions) the anchor survives in source.
#
# Usage:
#   scripts/verify-anchor.sh                # local check, no upstream clone
#   scripts/verify-anchor.sh --upstream     # also clone upstream and verify apply
#
# Exit codes:
#   0  all checks passed
#   1  at least one check failed
#   2  invalid usage

set -euo pipefail

ANCHOR="QUECTEL_THROUGHPUT_ANCHOR"
DO_UPSTREAM=0
if [[ "${1:-}" == "--upstream" ]]; then
    DO_UPSTREAM=1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
patches_dir="${repo_root}/patches"

errors=0

echo "==> Checking 01-anchor.patch files contain ${ANCHOR}..."
for f in "${patches_dir}"/*/01-anchor.patch; do
    [[ -e "$f" ]] || continue
    version="$(basename "$(dirname "$f")")"
    if grep -q "${ANCHOR}" "$f"; then
        echo "    [OK] ${version}/01-anchor.patch contains ${ANCHOR}"
    else
        echo "    [FAIL] ${version}/01-anchor.patch missing ${ANCHOR}"
        errors=$((errors + 1))
    fi
done

# Also check _template.patch.
if [[ -f "${patches_dir}/_template.patch" ]]; then
    if grep -q "${ANCHOR}" "${patches_dir}/_template.patch"; then
        echo "    [OK] _template.patch contains ${ANCHOR}"
    else
        echo "    [FAIL] _template.patch missing ${ANCHOR}"
        errors=$((errors + 1))
    fi
fi

if [[ "${DO_UPSTREAM}" -eq 1 ]]; then
    echo "==> Checking anchor survives after apply on upstream (tested versions only)..."

    for f in "${patches_dir}"/*/source.json; do
        [[ -e "$f" ]] || continue
        version="$(basename "$(dirname "$f")")"

        # Only verify versions with non-empty tested_at
        if ! grep -q '"tested_at": *"[^"]\+"' "$f"; then
            echo "    [SKIP] ${version}: tested_at is empty, skipping upstream check"
            continue
        fi

        commit="$(grep -oE '"commit": *"[^"]+"' "$f" | head -n1 | sed 's/.*"\([^"]*\)".*/\1/')"
        if [[ -z "${commit}" ]]; then
            echo "    [SKIP] ${version}: no commit hash"
            continue
        fi

        work_dir="$(mktemp -d)"
        trap 'rm -rf "${work_dir}"' EXIT

        if ! git clone --depth 1 "${commit}" \
            "https://github.com/linux-mobile-broadband/ModemManager.git" \
            "${work_dir}/mm" >/dev/null 2>&1; then
            echo "    [FAIL] ${version}: failed to clone upstream at ${commit}"
            errors=$((errors + 1))
            continue
        fi

        if ! git -C "${work_dir}/mm" apply --check "${patches_dir}/${version}/01-anchor.patch" 2>/dev/null; then
            echo "    [FAIL] ${version}: 01-anchor.patch does not apply on upstream ${commit}"
            errors=$((errors + 1))
            continue
        fi
        git -C "${work_dir}/mm" apply "${patches_dir}/${version}/01-anchor.patch" 2>/dev/null

        count="$(git -C "${work_dir}/mm" grep -c "${ANCHOR}" src/mm-port-qmi.c 2>/dev/null || echo 0)"
        if [[ "${count}" == "1" ]]; then
            echo "    [OK] ${version}: anchor appears exactly 1 time on upstream ${commit}"
        else
            echo "    [FAIL] ${version}: anchor appears ${count} times (expected 1)"
            errors=$((errors + 1))
        fi

        rm -rf "${work_dir}"
    done
fi

if [[ "${errors}" -gt 0 ]]; then
    echo "==> ${errors} check(s) failed."
    exit 1
fi
echo "==> All anchor checks passed."