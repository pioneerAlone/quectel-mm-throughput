# Upstream Tracking

How to monitor ModemManager releases and decide when to add a new patch version to this repository.

## Monitoring sources

| Source | URL | Notification method |
|--------|-----|---------------------|
| Mailing list (canonical) | `modemmanager-devel@lists.freedesktop.org` | Subscribe to receive `[ANN]` release posts |
| Mailing list archive | <https://lists.freedesktop.org/archives/modemmanager-devel/> | Manual check |
| GitLab releases | <https://gitlab.freedesktop.org/mobile-broadband/ModemManager/-/releases> | RSS feed (sign in to enable) |
| GitHub mirror tags | <https://github.com/linux-mobile-broadband/ModemManager/tags> | "Watch → Custom → Releases" |
| CI weekly scan | This repo's `upstream-compat` workflow | Issues are auto-opened on failure |

## Cadence

ModemManager typically releases:

- A major version (X.0) every ~2 years (e.g., 1.20 → 1.22 → 1.24)
- Minor versions (X.Y) every 6-12 months within a major series
- Micro versions (X.Y.Z) as needed for critical bug fixes

Recent timeline (verified via web search 2026-07):

| Version | Release date |
|---------|--------------|
| 1.18.0  | ~2022 |
| 1.20.0  | ~2023 |
| 1.22.0  | 2024-04-30 |
| 1.24.0  | ~2025 |

## When to bump this repo's compatibility matrix

Add a new entry to `patches/<new-version>/` when:

1. The new version is **stable** (i.e., released by upstream, not a release candidate), AND
2. **One of**:
   - The new version is a major bump (e.g., 1.22 → 1.24): always add
   - The new version is a minor bump within the current major: add if `git apply --check` of existing patches fails
   - The new version is a micro bump (e.g., 1.22.0 → 1.22.1): usually no action needed unless it touches `mm-port-qmi.c`

## When to bump the runtime adapter

Add `runtime/adapters/<major>.<minor>.sh` when:

1. `mmcli --output-keyvalue -L` field names change, OR
2. Bearer properties change, OR
3. D-Bus paths change

If none of these change, you may reuse the previous adapter.

## Bump workflow

```bash
# 1. From the repo root
./scripts/bump-upstream.sh 1.26.0

# 2. Manually rebase the patches (see docs/anchor-strategy.md § "How to rebase")

# 3. Manually verify on a fresh upstream clone:
cd /tmp && rm -rf verify
git clone --depth 1 --branch 1.26.0 https://github.com/linux-mobile-broadband/ModemManager.git verify
cd verify
git apply /path/to/quectel-mm-throughput/patches/1.26.0/01-anchor.patch
git apply /path/to/quectel-mm-throughput/patches/1.26.0/02-ul-agg.patch
# Confirm anchor count == 1 and UL AGG lines present

# 4. Run validation scripts
./scripts/verify-anchor.sh --upstream
./scripts/check-compat-matrix.sh

# 5. Update SUPPORTED.md and CHANGES.md

# 6. Commit & push
git add patches/1.26.0/
git commit -m "patches: add 1.26.0 rebase"
git push origin main
```

## CI monitoring

The `upstream-compat` workflow in `.github/workflows/` runs weekly and:

- Pulls each declared MM version from the GitHub mirror
- Tries to apply `01-anchor.patch` and `02-ul-agg.patch`
- On failure, opens a GitHub Issue titled "upstream-compat: <version> failed"

When such an issue is opened, follow the bump workflow above.

## Notifications

To get notified about new ModemManager releases:

1. Subscribe to `modemmanager-devel@lists.freedesktop.org`
2. Watch the GitHub mirror repository
3. Add the GitLab RSS feed to your reader
4. Check the `upstream-compat` weekly CI run for new warnings

## What we explicitly do NOT track

- libqmi, libmbim, libqrtr-glib independent releases: their versioning is decoupled from ModemManager. We only care about them when MM bumps its dependency requirement.
- ModemManager distribution packages (Debian, Arch, etc.): out of scope. Each distribution has its own patching logic.