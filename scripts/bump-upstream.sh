#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# bump-upstream.sh — create placeholder patch directory for a new MM version.
#
# Usage:
#   scripts/bump-upstream.sh <new-mm-version>
# Example:
#   scripts/bump-upstream.sh 1.26.0
#
# What it does:
#   1. mkdir patches/<new-mm-version>/
#   2. clone upstream tag from GitHub mirror
#   3. extract commit hash and write source.json
#   4. pre-populate 01-anchor.patch and 02-ul-agg.patch with TODO content
#
# After running this:
#   - Review the generated 01-anchor.patch placeholder
#   - Apply the placeholder to the cloned source to verify it applies
#   - Manually rebase 02-ul-agg.patch
#   - Update source.json tested_at and tested_by

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <new-mm-version>" >&2
    echo "Example: $0 1.26.0" >&2
    exit 64
fi

new_version="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_dir="${repo_root}/patches/${new_version}"

if [[ -d "${target_dir}" ]]; then
    echo "Error: ${target_dir} already exists" >&2
    echo "Refusing to overwrite. Remove it first if you really want to redo." >&2
    exit 1
fi

echo "==> Creating ${target_dir}"
mkdir -p "${target_dir}"

echo "==> Cloning upstream tag ${new_version} (shallow, GitHub mirror)"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

git clone --depth 1 --branch "${new_version}" \
    https://github.com/linux-mobile-broadband/ModemManager.git \
    "${work_dir}/mm" 2>&1 | sed 's/^/    /'

commit="$(git -C "${work_dir}/mm" rev-parse HEAD)"
echo "==> Commit: ${commit}"

# Write source.json with patch_files pre-populated, tested_at/by empty.
cat > "${target_dir}/source.json" <<EOF
{
  "mm_version": "${new_version}",
  "upstream_repo": "linux-mobile-broadband/ModemManager",
  "upstream_canonical": "https://gitlab.freedesktop.org/mobile-broadband/ModemManager",
  "ref": "${new_version}",
  "commit": "${commit}",
  "files_touched": ["src/mm-port-qmi.c"],
  "patch_files": ["01-anchor.patch", "02-ul-agg.patch"],
  "apply_order": ["01-anchor.patch", "02-ul-agg.patch"],
  "tested_at": "",
  "tested_by": "",
  "notes": "Placeholder created by scripts/bump-upstream.sh. Manual rebase of 02-ul-agg.patch still required."
}
EOF

# Write 01-anchor.patch as TODO + reference template.
cat > "${target_dir}/01-anchor.patch" <<'EOF'
# TODO: rebase anchor to upstream <new-mm-version>
#
# Steps:
#   1. cd "${work_dir}/mm" (already done by bump-upstream.sh)
#   2. Find a stable insertion point near sync_wda_data_format() in src/mm-port-qmi.c.
#      Use the DOWNLINK DATA AGGREGATION section as the anchor.
#   3. Insert the QUECTEL_THROUGHPUT_ANCHOR comment block (see patches/1.22.0/01-anchor.patch
#      for the exact format).
#   4. git diff src/mm-port-qmi.c > <repo>/patches/<new-mm-version>/01-anchor.patch
EOF

# Write 02-ul-agg.patch as TODO + reference.
cat > "${target_dir}/02-ul-agg.patch" <<'EOF'
# TODO: rebase UL AGG patch against MM <new-mm-version>
#
# Steps:
#   1. cd "${work_dir}/mm"
#   2. git apply <repo>/patches/<new-mm-version>/01-anchor.patch
#   3. Insert the 2 UL AGG lines AFTER the QUECTEL_THROUGHPUT_ANCHOR comment:
#        qmi_message_wda_set_data_format_input_set_uplink_data_aggregation_max_size (input, 4096, NULL);
#        qmi_message_wda_set_data_format_input_set_uplink_data_aggregation_max_datagrams (input, 11, NULL);
#   4. git diff src/mm-port-qmi.c > <repo>/patches/<new-mm-version>/02-ul-agg.patch
#   5. Update source.json: set tested_at, tested_by, notes.
#   6. Run scripts/verify-anchor.sh to validate.
EOF

echo "==> Done."
echo "    Created: ${target_dir}/"
echo "    Next:   manually rebase 01-anchor.patch and 02-ul-agg.patch,"
echo "             then update source.json tested_at / tested_by / notes."