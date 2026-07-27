#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# apply-patches.sh — clone upstream ModemManager and apply this repo's patches.
#
# Usage:
#   scripts/apply-patches.sh [<mm-version>] [<target-dir>]
#   scripts/apply-patches.sh --help
#
# Examples:
#   scripts/apply-patches.sh                          # default: 1.22.0 → ./upstream
#   scripts/apply-patches.sh 1.22.0                   # explicit version
#   scripts/apply-patches.sh 1.24.0 /tmp/mm-build     # custom target dir
#   scripts/apply-patches.sh --check 1.22.0           # verify-only mode
#   scripts/apply-patches.sh --source gitlab 1.22.0   # use GitLab canonical
#
# Exit codes:
#   0  patches applied (or --check passed) successfully
#   1  general error
#   2  invalid arguments
#   3  patch apply failed
#   4  post-apply verification failed

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults & arg parsing
# ---------------------------------------------------------------------------

DEFAULT_VERSION="1.22.0"
DEFAULT_TARGET_DIR="./upstream"
DEFAULT_SOURCE="github"   # github | gitlab

SOURCE="$DEFAULT_SOURCE"
VERSION=""
TARGET_DIR=""
CHECK_ONLY=0
CLEAN=0
PRINT_HELP=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] [<mm-version>] [<target-dir>]

Options:
  --check              Verify patches would apply, do not modify files
  --clean              Remove target-dir before cloning
  --source <name>      Upstream source: github (default) | gitlab
  --version <v>        ModemManager version to apply patches for
  --help               Show this help

Positional args:
  <mm-version>         ModemManager version (e.g. 1.22.0)
  <target-dir>         Directory to clone into (default: ./upstream)

Environment variables:
  MM_VERSION           Default MM version if not passed as argument
  MM_TARGET_DIR        Default target dir if not passed as argument
  MM_SOURCE            github | gitlab

Examples:
  $(basename "$0")                                  # 1.22.0 → ./upstream
  $(basename "$0") 1.22.0                           # explicit version
  $(basename "$0") 1.24.0 /tmp/mm-build             # custom target dir
  $(basename "$0") --check 1.22.0                   # dry-run verification
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            PRINT_HELP=1
            shift
            ;;
        --check)
            CHECK_ONLY=1
            shift
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --source)
            SOURCE="${2:-}"
            shift 2
            ;;
        --version)
            VERSION="${2:-}"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            # First positional = version, second = target-dir
            if [[ -z "$VERSION" ]]; then
                VERSION="$1"
            elif [[ -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
            else
                echo "Too many positional arguments" >&2
                usage >&2
                exit 2
            fi
            shift
            ;;
    esac
done

if [[ "$PRINT_HELP" -eq 1 ]]; then
    usage
    exit 0
fi

# Fill from env vars if still unset.
: "${VERSION:=${MM_VERSION:-$DEFAULT_VERSION}}"
: "${TARGET_DIR:=${MM_TARGET_DIR:-$DEFAULT_TARGET_DIR}}"

# Validate
case "$SOURCE" in
    github|gitlab) ;;
    *)
        echo "Invalid --source: $SOURCE (must be github or gitlab)" >&2
        exit 2
        ;;
esac

case "$VERSION" in
    1.*.*) ;;
    *)
        echo "Version must look like X.Y.Z (got: $VERSION)" >&2
        exit 2
        ;;
esac

# ---------------------------------------------------------------------------
# Resolve source URL & commit from source.json
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATCH_DIR="${REPO_ROOT}/patches/${VERSION}"
SOURCE_JSON="${PATCH_DIR}/source.json"

if [[ ! -d "$PATCH_DIR" ]]; then
    echo "No patches directory for MM ${VERSION}: ${PATCH_DIR}" >&2
    echo "Run scripts/bump-upstream.sh ${VERSION} to create placeholders." >&2
    exit 1
fi

if [[ ! -f "$SOURCE_JSON" ]]; then
    echo "Missing ${SOURCE_JSON}" >&2
    exit 1
fi

# Extract commit + files via simple grep (avoid jq dependency)
COMMIT="$(grep -oE '"commit"[[:space:]]*:[[:space:]]*"[^"]+"' "$SOURCE_JSON" | \
    head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"

if [[ -z "$COMMIT" ]]; then
    echo "Could not parse commit from ${SOURCE_JSON}" >&2
    exit 1
fi

case "$SOURCE" in
    github)
        UPSTREAM_URL="https://github.com/linux-mobile-broadband/ModemManager.git"
        ;;
    gitlab)
        # Note: GitLab canonical has Anubis bot protection that may block CI.
        UPSTREAM_URL="https://gitlab.freedesktop.org/mobile-broadband/ModemManager.git"
        ;;
esac

# ---------------------------------------------------------------------------
# Clone (or reuse) the upstream source
# ---------------------------------------------------------------------------

if [[ -d "$TARGET_DIR" ]]; then
    if [[ "$CLEAN" -eq 1 ]]; then
        echo "==> --clean: removing existing ${TARGET_DIR}"
        rm -rf "$TARGET_DIR"
    else
        echo "==> ${TARGET_DIR} already exists; reusing (use --clean to remove)"
    fi
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "==> Cloning upstream ${SOURCE} at commit ${COMMIT}"
    git init -q "$TARGET_DIR"
    git -C "$TARGET_DIR" remote add origin "$UPSTREAM_URL"
    git -C "$TARGET_DIR" fetch --depth 1 origin "$COMMIT"
    git -C "$TARGET_DIR" checkout -q FETCH_HEAD
else
    # Verify the existing clone is at the expected commit.
    existing_commit="$(git -C "$TARGET_DIR" rev-parse HEAD 2>/dev/null || echo "")"
    if [[ "$existing_commit" != "$COMMIT" ]]; then
        echo "==> Existing clone at $existing_commit != expected $COMMIT" >&2
        echo "    Use --clean to re-clone, or pass a different target-dir." >&2
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Apply patches in order
# ---------------------------------------------------------------------------

PATCH_FILES="$(grep -oE '"patch_files"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$SOURCE_JSON" | \
    head -n1 | \
    sed -E 's/.*\[([^]]*)\].*/\1/' | \
    tr ',' '\n' | \
    sed -E 's/^[[:space:]]*"(.*)"[[:space:]]*$/\1/')"

if [[ -z "$PATCH_FILES" ]]; then
    echo "Could not parse patch_files from ${SOURCE_JSON}" >&2
    exit 1
fi

for patch in $PATCH_FILES; do
    patch_path="${PATCH_DIR}/${patch}"
    if [[ ! -f "$patch_path" ]]; then
        echo "Missing patch file: ${patch_path}" >&2
        exit 1
    fi

    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        # In --check mode, apply patches cumulatively because later patches
        # may depend on earlier ones. The cleanup at the end resets state.
        echo "==> --check: verifying ${patch} (cumulative)"
        if ! git -C "$TARGET_DIR" apply --check "$patch_path"; then
            echo "    FAIL: ${patch} does not apply cleanly" >&2
            exit 3
        fi
        # Apply it so the next iteration sees the cumulative state.
        git -C "$TARGET_DIR" apply "$patch_path"
        echo "    OK"
    else
        echo "==> Applying ${patch}"
        if ! git -C "$TARGET_DIR" apply "$patch_path"; then
            echo "    FAIL: ${patch} could not be applied" >&2
            exit 3
        fi
        echo "    OK"
    fi
done

# In --check mode, reset the working tree so we leave no side effects.
if [[ "$CHECK_ONLY" -eq 1 ]]; then
    git -C "$TARGET_DIR" checkout -- . >/dev/null 2>&1 || true
    echo "==> (--check: working tree reset to clean upstream)"
fi

# ---------------------------------------------------------------------------
# Post-apply verification
# ---------------------------------------------------------------------------

if [[ "$CHECK_ONLY" -eq 0 ]]; then
    echo "==> Verifying post-apply state..."
    for file in src/mm-port-qmi.c; do
        # git grep -c outputs "<file>:<count>" — extract just the count.
        anchor_raw="$(git -C "$TARGET_DIR" grep -c QUECTEL_THROUGHPUT_ANCHOR -- "$file" 2>/dev/null || echo 0)"
        anchor_count="${anchor_raw##*:}"
        if [[ "$anchor_count" != "1" ]]; then
            echo "    FAIL: anchor count is ${anchor_count} (expected 1) in ${file}" >&2
            exit 4
        fi
        echo "    OK: ${file} contains exactly 1 anchor"

        # Count distinct UL AGG lines: max_size with 4096 and max_datagrams with 11.
        agg_size_count="$(grep -c 'uplink_data_aggregation_max_size.*4096' "$TARGET_DIR/$file" || true)"
        agg_dat_count="$(grep -c 'uplink_data_aggregation_max_datagrams.*11' "$TARGET_DIR/$file" || true)"
        if [[ "$agg_size_count" != "1" || "$agg_dat_count" != "1" ]]; then
            echo "    FAIL: expected max_size/4096=1 max_datagrams/11=1, got size=${agg_size_count} datagrams=${agg_dat_count}" >&2
            exit 4
        fi
        echo "    OK: ${file} contains UL AGG lines (max_size=4096, max_datagrams=11)"
    done
fi

echo "==> Done."
if [[ "$CHECK_ONLY" -eq 1 ]]; then
    echo "    All patches verify cleanly for MM ${VERSION} at commit ${COMMIT}."
else
    echo "    MM ${VERSION} source at ${TARGET_DIR} is patched and ready to build."
fi