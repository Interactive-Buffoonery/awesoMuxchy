# SwiftGtk4 viability

Decision: **pass** on 2026-08-28.

SwiftGtk is suitable for continuing the awesoMux Linux implementation. The
required lifecycle is understandable, raw pointers are contained in one small
wrapper boundary, owned Swift code builds cleanly under Swift 6.3.3, and the
real renderer remains stable under repeated multi-surface teardown. Continue
through the root implementation order.

## Evidence

### Build reproducibility

- Swift 6.3.3 and Zig 0.16.0 are verified repo-local toolchains.
- SwiftGtk and every resolved Swift dependency are locked to immutable Git
  revisions in `Package.resolved`.
- Ghostty and zmx are pinned submodules. Ghostty is patched only in a disposable
  staged copy, and the canonical submodule stays clean.
- GTK4 uses the approved system development package. Until the approved ATK
  package can be installed system-wide, `script/stage-atk-dev.sh` extracts its
  development archive into the ignored build sysroot without root access.
- `script/preflight.sh` is the single local build/test/release authority.

### GTK API coverage

The vertical slice uses a real `GtkApplication`, one native window, GTK boxes,
buttons, a paned split, `GtkGLArea`, focus/key/motion/click/scroll controllers,
`GtkIMContext`, `GdkClipboard`, and GTK accessibility properties. The APIs
needed for the larger product are available; generated naming is occasionally
awkward but does not require broad unsafe access.

### Ghostty callback safety

- Wakeups enter the GLib main context before ticking Ghostty.
- Surface teardown marks the host dead before freeing the core and disconnects
  all GTK signals.
- Asynchronous clipboard completions check teardown state. The host allocation
  remains alive until all pending callbacks return.
- Three standalone runs each created, realized, exercised, and destroyed 100
  generations of two concurrently busy surfaces without a crash, hang, or
  stale callback.

### GObject and Swift ownership

`AwesoMuxTerminal.TerminalRuntime` owns the Ghostty application handle.
`TerminalSurface` retains its runtime, owns exactly one shim handle, and exposes
only a managed `WidgetRef` plus narrow operations. Application state releases
surfaces before the runtime. GTK mutation stays on the application main thread.

### Swift 6 concurrency

Owned Swift code builds without concurrency warnings. GTK and Ghostty handles
are not declared `Sendable`; generated GTK types are not passed to Swift tasks.
The only global mutable values retain main-thread application state across the
C application callback and are explicitly marked `nonisolated(unsafe)` at that
single boundary.

### Input-method correctness

The shim owns a `GtkIMMulticontext`, filters key events, forwards preedit text,
and commits UTF-8 through Ghostty. The integration harness verifies composed
data containing an accent, an explicit combining mark, emoji, and a wide CJK
character. A real desktop IME preedit session remains required before parity is
declared complete.

### Accessibility feasibility

GTK provides native button semantics for sidebar rows, native focus state for
the terminal GL areas, and explicit terminal labels/descriptions through
`GtkAccessible`. This is enough to proceed. Orca/AT-SPI traversal and state
announcement testing remain part of the accessibility phase.

### Debug experience

Swift compile errors are readable and LLDB-compatible binaries are produced.
The slowest clean-build step is GIR generation. Two small audited gir2swift
patches add a configured GIR search path so repo-local development metadata can
be used without modifying the machine.

### Packaging feasibility

Debug and release executables launch directly outside `swift run` when the
staged library directory is present. A Linux package must bundle the Swift
runtime, shim, Ghostty library, GL loader, resources, and their notices, then
set an internal runtime search path. No packaging blocker was found.

### Remaining unsafe/raw code

Raw C is limited to the language-neutral Ghostty/GTK shim and generated GTK
bindings. The owned shim is the necessary ABI and event/lifecycle boundary;
product models and routing remain ordinary Swift value/reference types. No
unsafe pointer is exposed to the application target.

### SwiftGtk maintenance

- Maintain immutable dependency revisions because several upstream packages
  publish moving branches.
- Maintain the two small `GIR2SWIFT_GIR_PATH` patches until upstream supports
  configured GIR search directories.
- SwiftPM reports prohibited transitive C flags such as `-pthread`; these are
  dependency-manifest diagnostics, not suppressed owned-code warnings.
- The generated API surface is large and compile time is material, but the
  required wrapper layer stays small.

## Resolved non-Swift constraint

Native GTK Wayland originally failed to create a desktop OpenGL context on the
COSMIC/NVIDIA GTX 1080 Ti configuration, including a minimal two-GLArea run.
The cause was GTK 4.14 selecting its GLES path before the per-widget desktop-GL
restriction took effect. Preparing GTK with canonical Ghostty's version-aware
desktop-OpenGL environment selection resolves the failure. Native integration,
100 two-surface lifecycle cycles, 100%/125%/150%/200% scale runs, and an
inspected real-app capture now pass; X11/GLX remains covered as a regression.
