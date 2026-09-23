# Linux consolidation — 2026-09-22

Swift/GTK/Ghostty is the active Linux implementation. This cleanup preserves
useful Electron work and makes GTK independent of the Electron repository's
continued availability. It does not claim new runtime behavior or parity.

## Baseline and preservation

| Item | Recorded state |
| --- | --- |
| GTK source baseline | `c822966875683e836d2bd2d00488a9d8c5850669` |
| Cleanup branch | `chore/consolidate-linux-development` |
| Electron final fetched source | `ee95c6a74910ff8a8b1d01493e8a4c192e3199c1` |
| Preserved Electron material | Complete 36-commit Git bundle, 201 tracked tip files, license and metadata under `reference/legacy-electron/` |
| GTK extra remote branch | `visual-qa/main-window-160c2b1` at `ce4a609ba1f92e001b3467add3c3e2fdc8926307`; one documentation/screenshots commit ahead of GTK main |
| Product/text baseline | `fed33ff47c559344fc6db6fa53f16e75fcc4a116`; unchanged by this cleanup |

Read the [Electron behavior handoff](electron-behavior-handoff.md) for contracts
and regression scenarios, and the [archive guide](../reference/legacy-electron/README.md)
for offline restoration. No Electron runtime code or dependencies were added to
the GTK application. Its checkout remains an untouched reference.

## Unpublished GTK work is unresolved

The September 5 index on `visual-qa/main-window-160c2b1` describes local
implementation commit `98c4691` and additional uncommitted implementation and
baseline updates on i5GamingPC. GitHub cannot resolve that commit. The branch
adds only the visual index, a macOS reference README, and nine PNGs; merging it
would not recover those implementation changes.

Its report of 134 passing tests and fixed Geist loading belongs to the recorded
local build. Published `main` still has the older `Fonts/`-only resource lookup
and preflight. Do not assign the branch's verification claims to this checkout.
The branch's main-window screenshots reference macOS `160c2b1`; earlier main
screenshots reference `2fd33a0`, while the executable text checker still pins
`fed33ff`. These are separate evidence baselines, not interchangeable pins.

A read-only attempt through the configured `i5gamingpc` SSH alias on September
22 failed with `No route to host`. No files on that machine were changed.
When it is reachable, inspect its branch, status, local commit `98c4691`, and
unstaged/staged diffs before applying overlapping visual or font changes.
Preserve the local work before rebasing, resetting, or cleaning anything.
Reconcile source revisions and evidence explicitly; do not cherry-pick the
screenshot branch as an implementation fix.

## Next work, in dependency order

1. Recover/reconcile i5 local work and record one reproducible source baseline.
2. Verify and fix the application close path, bounded saves under sustained
   activity, clipboard confirmations, shell exit/restart, and recovery storage.
3. Integrate one persistent local `amx` pane; distinguish creation from
   existing-session recovery and prove same-process reattachment after a
   frontend crash. Then extend to split workspaces and close semantics.
4. Complete Claude Code and Codex lifecycle hooks, installation/repair and
   native notification actions. Agent event endpoints must remain usable when
   shells survive frontend restarts.
5. Reproduce a clean local build and staged launch, then validate keyboard,
   pointer, clipboard, real IME, Orca, and scale behavior on target desktops.

Full SSH, document, auxiliary-window, settings, and visual parity remain the
product destination. The next milestone is dependable local daily use; this
cleanup does not mark any deferred feature complete.

## Reliability findings carried forward

These were traced in published source, not reproduced in a running GTK app:

- `ApplicationState.discardPaneRuntime` requests close, retains the surface,
  and polls for process exit; `TerminalSurface` installs no close callback.
  Canonical Ghostty's request-close route calls back to the host rather than
  terminating the child. Test the actual app-close path; the standalone stress
  harness instead drops its surface references directly.
- `SessionPersistenceCoordinator.schedule` resets a 500 ms trailing-edge
  timer on each change. Continued title/agent updates can keep invalidating
  writes until quiet or clean quit. macOS PR #583 subsequently changed to fixed
  save windows; port the behavioral fix and sustained-activity test, not an
  unreviewed platform service.
- The C shim auto-confirms paste confirmation requests and ignores clipboard
  writes' confirmation flag. Add explicit confirm/cancel and late-callback
  behavior before treating clipboard coverage as complete.
- `AgentEventEndpoint` and `AgentEventWatcher` currently create/remove
  frontend-owned event files. Persistent-shell integration must define endpoint
  and session identity across detach/reattach before real provider rollout.

Source locations: `swift-gtk/Sources/AwesoMuxApp/main.swift`,
`swift-gtk/Sources/AwesoMuxTerminal/TerminalRuntime.swift`,
`swift-gtk/Sources/AwesoMuxCore/SessionPersistenceCoordinator.swift`,
`swift-gtk/Sources/AwesoMuxCore/AgentEventFile.swift`, and
`ghostty-shim/src/awesomux_ghostty.c`.

## Validation and remaining limits

- Electron archive SHA-256 and complete offline mirror restoration passed,
  including `git fsck --full`, all captured refs, commit count, and tip tree.
- The committed text baseline's shape check passed. The macOS reference is not
  cloned here, so this does not establish live catalog comparison.
- Changed/new Markdown relative links, Python syntax, JSON parsing, and
  `git diff --check` passed. Independent review also restored the bundle using
  the documented ordinary-clone instructions and checked all 45 handoff source
  paths. Its two documentation findings were corrected.
- The checkout is on pinguchy at `~/development/awesomux-linux-gtk`; no Swift
  executable is installed on PATH and vendored submodules are uninitialized.
  `./script/preflight.sh` exited at its first prerequisite check with
  `preflight: verified repo-local Swift 6.3.3 is missing`. Swift tests, renderer
  tests, and desktop QA therefore did not run.
- No packages were installed; no dependency pins, renderer behavior, hosted
  workflows, GitHub repository settings, or remote source were changed.

## Before retiring Electron

The useful behavior and full fetched source are now locally preserved. To make
deletion safe beyond this machine, publish the reviewed GTK consolidation,
verify `python3 script/verify-electron-archive.py` from a fresh clone, and check
old Electron worktrees for local-only changes. No additional Electron release,
issue, PR, wiki, or Actions artifact migration was needed at inventory time.
Archiving is reversible; deletion is a separate final action. This cleanup
performs neither and does not authorize either automatically.
