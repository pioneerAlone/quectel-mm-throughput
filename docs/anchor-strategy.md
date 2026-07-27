# Anchor Strategy

This document explains why each ModemManager version in `patches/` has TWO patches instead of one, and how to maintain them as upstream ModemManager evolves.

## Why split into two patches

A single patch that combines "insert anchor comment" + "add UL AGG lines" would fail to apply as soon as upstream ModemManager modifies any context line near the insertion point. Splitting decouples the two concerns:

| Patch | Role | Stability |
|-------|------|-----------|
| `01-anchor.patch` | Inserts the `QUECTEL_THROUGHPUT_ANCHOR` comment block | **High** — only inserts, no functional change |
| `02-ul-agg.patch` | Inserts the actual UL AGG `qmi_message_wda_set_data_format_input_set_*` calls | **Medium** — depends on 01 having been applied |

The **order of application is mandatory**: `01-anchor.patch` MUST be applied before `02-ul-agg.patch`. This is enforced by:

- The `apply_order` field in `source.json`
- The `scripts/verify-anchor.sh` script
- The `runtime/README.md` quick-start instructions

## Why a magic comment string

The anchor string `QUECTEL_THROUGHPUT_ANCHOR` serves three purposes:

1. **Git-blame discoverability**: any developer running `git blame` on the patched file sees the magic string and can search for its origin
2. **Reverse reference**: the comment text contains the GitHub URL, so upstream developers encountering it can contact us
3. **CI guardrail**: `scripts/verify-anchor.sh --upstream` ensures the anchor survives after every apply

## When the anchor breaks

The anchor will fail to apply when upstream ModemManager:

- **Renames** the function `sync_wda_data_format` → fix: update `01-anchor.patch`'s hunk header (`@@ ... @@ sync_wda_data_format`) and regenerate
- **Restructures** the WDA input-building section → fix: re-find a stable insertion point and update both patches
- **Refactors** the QMI message helper calls → fix: regenerate `02-ul-agg.patch` with new function names
- **Moves** the code to a different file (e.g., `mm-port-qmi-wda.c`) → fix: update `files_touched` in `source.json` and rebase both patches to the new path

## How to rebase to a new MM version

The recommended workflow is:

```bash
# 1. Create placeholder directory
scripts/bump-upstream.sh 1.26.0

# 2. Open the cloned upstream source (in /tmp) and locate the new sync_wda_data_format
cd /tmp/mm*/src
grep -n "sync_wda_data_format\|set_downlink_data_aggregation_max_datagrams" mm-port-qmi.c

# 3. Edit mm-port-qmi.c to add the QUECTEL_THROUGHPUT_ANCHOR comment block:
#    /* QUECTEL_THROUGHPUT_ANCHOR
#     *   Uplink aggregation applied here.
#     *   See https://github.com/pioneerAlone/quectel-mm-throughput
#     *   Do NOT delete this comment unless you also remove
#     *   the matching UL AGG lines.
#     */
git diff src/mm-port-qmi.c > /path/to/quectel-mm-throughput/patches/1.26.0/01-anchor.patch

# 4. Apply 01-anchor.patch to the same source
git apply --check /path/to/quectel-mm-throughput/patches/1.26.0/01-anchor.patch
git apply /path/to/quectel-mm-throughput/patches/1.26.0/01-anchor.patch

# 5. Add the 2 UL AGG lines AFTER the QUECTEL_THROUGHPUT_ANCHOR comment
# (Use the lines from patches/1.22.0/02-ul-agg.patch as a template — the function
#  names may have changed; update them to match the new qmi_message_*_input_set_uplink_*)

# 6. Generate 02-ul-agg.patch
git diff src/mm-port-qmi.c > /path/to/quectel-mm-throughput/patches/1.26.0/02-ul-agg.patch

# 7. Verify both apply cleanly on a fresh upstream clone
cd /tmp && rm -rf verify
git clone --depth 1 --branch 1.26.0 https://github.com/linux-mobile-broadband/ModemManager.git verify
cd verify
git apply /path/to/quectel-mm-throughput/patches/1.26.0/01-anchor.patch
git apply /path/to/quectel-mm-throughput/patches/1.26.0/02-ul-agg.patch
# Confirm:
grep -c QUECTEL_THROUGHPUT_ANCHOR src/mm-port-qmi.c   # must be 1
grep -c "uplink_data_aggregation_max_size.*4096" src/mm-port-qmi.c   # must be 1

# 8. Update source.json: tested_at, tested_by, notes

# 9. Update runtime/adapters/1.26.sh if MM minor version changed
#    (Use diff between 1.22.sh and 1.24.sh as guidance.)

# 10. Update SUPPORTED.md

# 11. Run scripts/check-compat-matrix.sh to verify everything is consistent

# 12. Commit, push, open PR
```

## Why not just submit upstream?

Two reasons we maintain this as an out-of-tree patch set rather than upstream contribution:

1. **Quectel-specific parameters**: 4096/11/1000us are validated against Quectel modems. The upstream maintainers may prefer generic defaults that work across all vendors.
2. **Iterative testing cycle**: shipping a tested patch set as a release artifact is faster than waiting for upstream review cycles (typically 3-6 months).

If upstream ModemManager eventually exposes UL AGG via a runtime-configurable property, this entire patch set can be retired in favor of MM-native configuration.

## Trade-offs

| Aspect | Two-patch strategy | Single-patch strategy |
|--------|---------------------|------------------------|
| Apply success rate | High (anchor survives more upstream changes) | Lower (single context match required) |
| Maintenance overhead | Two files per version | One file per version |
| Diff reviewability | Comments + functional change separated | Mixed in one hunk |
| Patch tooling support | Standard `git apply` | Standard `git apply` |