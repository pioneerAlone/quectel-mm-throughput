#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# check-compat-matrix.sh — validate SUPPORTED.md is consistent with the
# actual patches/ and runtime/adapters/ directory contents.
#
# Usage:
#   scripts/check-compat-matrix.sh
#
# Validation:
#   - Every MM version referenced in SUPPORTED.md must exist in patches/
#   - Every patches/<version>/ directory must be referenced in SUPPORTED.md
#   - Every runtime/adapters/<version>.sh (excluding _loader.sh) must be referenced

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
supported="${repo_root}/SUPPORTED.md"
patches_dir="${repo_root}/patches"
adapters_dir="${repo_root}/runtime/adapters"

errors=0

# Versions declared in SUPPORTED.md (extract from Markdown table rows like "| 1.22.0  |")
echo "==> Parsing SUPPORTED.md..."
declared_versions="$(grep -oE '^\| *[0-9]+\.[0-9]+\.[0-9]+ *\|' "${supported}" | \
    sed -E 's/^\| *([0-9.]+) *\|.*/\1/' | sort -u)"
echo "    Declared: $(printf '%s ' ${declared_versions})"

# Versions present as patches/ directories.
actual_patch_versions="$(find "${patches_dir}" -mindepth 1 -maxdepth 1 -type d | \
    xargs -n1 basename | sort -u)"
echo "    In patches/: $(printf '%s ' ${actual_patch_versions})"

# Adapter versions (excluding _loader.sh)
adapter_versions="$(find "${adapters_dir}" -mindepth 1 -maxdepth 1 -type f -name '[0-9]*.sh' | \
    xargs -n1 basename | sed -E 's/\.sh$//' | sort -u)"
echo "    In adapters/: $(printf '%s ' ${adapter_versions})"

# Check 1: every declared version exists as a patches/ dir
echo "==> Check 1: declared version must have patches/<v>/..."
for v in ${declared_versions}; do
    if [[ ! -d "${patches_dir}/${v}" ]]; then
        echo "    [FAIL] ${v} declared in SUPPORTED.md but no patches/${v}/ dir"
        errors=$((errors + 1))
    else
        echo "    [OK] ${v}"
    fi
done

# Check 2: every patches/ dir is declared
echo "==> Check 2: patches/<v>/ must be declared in SUPPORTED.md..."
for v in ${actual_patch_versions}; do
    if ! grep -q "^| *${v} *|" "${supported}"; then
        echo "    [FAIL] patches/${v}/ exists but not declared in SUPPORTED.md"
        errors=$((errors + 1))
    else
        echo "    [OK] ${v}"
    fi
done

# Check 3: adapter files should be referenced (adapters use major.minor, e.g. 1.22)
echo "==> Check 3: adapter versions referenced in SUPPORTED.md..."
for adapter in ${adapter_versions}; do
    # Adapter file is "X.Y.sh"; we check if any SUPPORTED.md row begins with X.Y.*
    if grep -qE "^\| *${adapter%%.*}\.${adapter##*\.}\.[0-9]+ *\|" "${supported}"; then
        echo "    [OK] adapter ${adapter}"
    else
        echo "    [WARN] adapter ${adapter} has no matching row in SUPPORTED.md"
        # Don't count warnings as errors
    fi
done

if [[ "${errors}" -gt 0 ]]; then
    echo "==> ${errors} error(s) found."
    exit 1
fi
echo "==> All compat-matrix checks passed."