# Reference baseline

Recorded: 2026-08-28 (America/New_York)

Consolidation note, 2026-09-22: the macOS commit below remains the executable
text/parity baseline. Later screenshot references (`2fd33a0`, `160c2b1`) do not
silently change that pin. Historical machine paths below record the original
inspection; current tooling defaults to a sibling `awesomux-macos-reference`
checkout or `AWESOMUX_MACOS_REFERENCE`. See
[`docs/linux-consolidation.md`](docs/linux-consolidation.md) for missing local
implementation evidence and the reconciliation sequence.

## macOS product reference

- Repository: `https://github.com/Interactive-Buffoonery/awesomux.git`
- Read-only clone: `/home/sarah/Development/awesomux-macos-reference`
- Remote default branch: `main`
- Commit: `fed33ff47c559344fc6db6fa53f16e75fcc4a116`
- Commit subject: `chore(deps): update Ghostty to f2d5758f6305 (#474)`
- Reference status before inspection: clean
- Reference status after inspection: clean

The checked-out gitlinks are authoritative when prose is stale:

- Ghostty: `f2d5758f6305867dc36b36293c6165d8152b853e`
- zmx/amx fork: `67c6f63c9f27e96733015f3099363a92d73e836e`

`docs/ghostty-integration.md` still names an older Ghostty pin. The current
reference commit and gitlink above take precedence.

## Required material reviewed

The reference pass read `AGENTS.md`, `CONTEXT.md`, `README.md`, `Package.swift`,
`docs/architecture.md`, every ADR in `docs/adr/`,
`docs/ghostty-integration.md`, `docs/amx-automation.md`, `docs/shortcuts.md`,
`docs/ci.md`, `docs/code-review.md`, the command catalog, relevant product
models/settings/application sources, all design-system and user-resource
inventories, localization catalogs, fonts, icons, templates, and licenses.
`.agents/AGENTS.md` was not present. No GitHub issues were needed to settle the
initial inventory.

## Historical Electron reference

- Originally inspected: `fc4322b` in the i5GamingPC prototype checkout.
- Final fetched source preserved during consolidation:
  `ee95c6a74910ff8a8b1d01493e8a4c192e3199c1`.
- Archive: [`reference/legacy-electron/README.md`](reference/legacy-electron/README.md).
- Extracted behavior: [`docs/electron-behavior-handoff.md`](docs/electron-behavior-handoff.md).
- Role: historical Linux behavior and visual evidence; not an active production
  direction or required neighboring checkout. Its old prompts are superseded.
