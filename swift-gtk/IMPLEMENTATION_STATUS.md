# SwiftGtk4 implementation status

Updated: 2026-08-28

## Current phase

Viability, defensive restoration, and the first coherent sidebar/footer chrome
milestone are complete and locally verified.

## Completed

- Swift 6.3.3 builds the pinned SwiftGtk dependency graph without warnings in
  owned Swift code or concurrency-suppression flags.
- `AwesoMuxTerminal` contains every raw Ghostty handle and exposes owned Swift
  runtime/surface objects to the app and integration harnesses.
- Two concurrent real terminals render on X11/GLX, receive focus and resize,
  and support UTF-8 input plus GTK clipboard read/write callbacks.
- GTK signals are disconnected before release; pending clipboard reads keep
  the host allocation alive and cannot complete against a destroyed core.
- GTK focus-enter/leave events cross the language-neutral callback table and
  update Swift pane ownership; sidebar selection and direct pane clicks now
  converge on the same focused-surface route.
- The standalone terminal integration harness passes pane independence,
  process exit, callbacks from both focused surfaces, resize, Unicode, and
  clipboard read/write.
- Three 100-cycle, two-busy-surface stress runs pass with stable warmed peak
  memory.
- Accessible pane labels/descriptions and keyboard-operable sidebar buttons
  establish a usable AT-SPI path for the first slice.
- Debug and release executables link outside `swift run` through the staged
  shim and pinned Ghostty runtime.
- The real screenshot, direct GitHub link, and comparison notes are uploaded.
- Sidebar rows switch complete workspaces through a native GTK stack. The
  Development workspace owns a two-pane split and Review owns an independent
  terminal, all without exposing Ghostty handles to application code.
- Twenty-three state tests cover grouped snapshots, defensive limits, selection,
  ordering, split/focus/close mutations, command chords, round trips,
  profile-scoped paths, owner-only persistence, quarantine, and recovery.
- The app renders its GTK stack/sidebar directly from `SessionSnapshot`, and
  native GTK actions plus accelerators share `CommandCatalog` with tests.
- A real two-launch check restored profile state and maintained `0600`
  current/previous snapshots; invalid and oversized files are moved into a
  `0700` quarantine with `0600` file permissions.
- A fixed 188-point native sidebar now has a separate header, scrolling group
  body, and pinned 38-point idle footer. Search, disclosure, workspace creation,
  row selection, hover/focus styling, density, and metadata use the live
  `SessionSnapshot` state.
- Every workspace page owns a 38-point path bar below its real Ghostty surface.
  Direct pane focus and sidebar switching update sanitized focused-pane context;
  generation checks reject stale publication. Git/PR/actions remain absent
  until their context is implemented truthfully.

## Remaining vertical-slice hardening

- Native Wayland GL context creation on the current NVIDIA/COSMIC stack.
- Real desktop IME preedit/commit and Orca inspection.
- Automated pointer selection, hover, scroll, primary selection, and pending
  clipboard teardown tests.
- Close/recreate actions in the product UI rather than only the stress harness.
- Arrow/Home/End list navigation, Orca state inspection, richer group actions,
  and Git/PR path-bar enrichment remain after this chrome milestone.

See `VIABILITY.md` for the checkpoint decision and evidence.
