# SwiftGtk4 implementation status

Updated: 2026-08-28

## Current phase

Viability passed; production workspace/sidebar implementation is active.

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
- Nine state tests cover grouped snapshots, defensive validation, selection,
  split/focus/close mutations, round trips, and owner-only persistence.

## Remaining vertical-slice hardening

- Native Wayland GL context creation on the current NVIDIA/COSMIC stack.
- Real desktop IME preedit/commit and Orca inspection.
- Automated pointer selection, hover, scroll, primary selection, and pending
  clipboard teardown tests.
- Close/recreate actions in the product UI rather than only the stress harness.

See `VIABILITY.md` for the checkpoint decision and evidence.
