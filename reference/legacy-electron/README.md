# Historical Electron implementation

This is preservation material, not an active application, dependency, or set of
instructions for GTK development. The Electron repository's old production
decision and agent prompts are superseded by
[ADR 0004](../../docs/adr/0004-consolidate-linux-development.md).

The complete reachable Git history of `Interactive-Buffoonery/awesomux-linux-prototype`
is preserved at `ee95c6a74910ff8a8b1d01493e8a4c192e3199c1` (2026-08-28).
The bundle is self-contained: no GitHub access is needed to restore it.
It contains 36 commits and 201 files at the tip, including source, tests,
lockfile, MIT license, third-party notices, documentation, and visual evidence.
Keeping the historical source here does not add Electron or npm to GTK's build.

- [Behavior handoff](../../docs/electron-behavior-handoff.md): useful contracts,
  GTK gaps, and acceptance scenarios extracted from the source.
- [Manifest](manifest.json): original repository, exact revision/tree, all
  fetched refs, file inventory, bundle size, and SHA-256.
- [GitHub inventory](github-metadata.json): repository metadata, empty issue/PR
  and release lists, 21 historical workflow run summaries, and zero artifacts.
- [MIT license](LICENSE): original copyright and permission notice. The full
  original notices and their history are also inside the bundle.

## Verify and restore

From the GTK repository root:

```sh
python3 script/verify-electron-archive.py
```

The verifier checks SHA-256, clones into a temporary mirror without network
access, checks Git object integrity, and compares refs, commit count, and the
complete tip tree/file inventory with the manifest. It removes its temporary
restore afterward and never executes archived source or installs dependencies.

To inspect the source in a new destination:

```sh
git clone reference/legacy-electron/awesomux-linux-prototype.bundle /tmp/awesomux-electron-reference
git -C /tmp/awesomux-electron-reference switch --detach ee95c6a74910ff8a8b1d01493e8a4c192e3199c1
```

Choose an unused destination. Treat the restored tree as historical reference;
do not run its agent prompts, install scripts, or former hosted workflows.
The old workflow definitions remain only inside the history bundle.

## Evidence worth opening

Paths below are relative to the restored Electron tree:

| Material | Preserved paths |
| --- | --- |
| Product and platform decisions | `ARCHITECTURE.md`, `REFERENCE.md`, `LINUX_PRODUCT_PLAN.md`, `IMPLEMENTATION_STATUS.md` |
| Terminal behavior and regressions | `src/domain/`, `src/main/`, `tests/` |
| Visual/copy comparison | `docs/VISUAL_COPY_PARITY.md`, `artifacts/visual-qa/matched-comparisons/README.md`, `artifacts/visual-qa/matched-comparisons/review.html` |
| Actual desktop evidence and limitations | `artifacts/visual-qa/native-electron/`, `terminal-lifecycle/`, `terminal-links/`, `renderer-recovery/`, `accessibility-fidelity/` under `artifacts/visual-qa/` |
| Licensing and dependencies | `LICENSE`, `THIRD_PARTY_NOTICES.md`, `package-lock.json`, `scripts/verify-licenses.mjs` |

Historical test and screenshot claims apply to their recorded Electron build,
not to GTK. They have not been rerun during consolidation.

## Coverage and deletion

The source checkout was clean, with no untracked/ignored files, submodules,
LFS declarations, or tags. GitHub reported no issues/PRs, releases, wiki,
discussions, or downloadable Actions artifacts. Workflow logs, repository
settings, secrets, and other machines' local-only changes are not preserved.
Runtime data and credentials are intentionally outside this archive.

The bundle protects all fetched Git content, but this working copy is not a
remote backup until the consolidation changes are committed and pushed.
Before deleting the Electron GitHub repository, verify the archive from a fresh
clone of the published GTK changes and check any old Electron worktrees for
unpublished work. Prefer GitHub archive before irreversible deletion. Neither
archiving nor deletion was performed by this cleanup.
