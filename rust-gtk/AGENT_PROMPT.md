# Build the Rust GTK4 fallback edition of awesoMux Linux

Read the repository-root `AGENT_PROMPT.md` completely before following this
track-specific prompt. All root source, safety, GitHub, screenshot, parity, and
macOS read-only boundaries apply here.

This is the prepared fallback track in:

`/home/sarah/Development/awesomux-linux-gtk/rust-gtk`

Do not begin implementing this track unless Sarah explicitly activates it.
The active first implementation is `swift-gtk/`.

## Goal

If activated, build the complete Linux edition of awesoMux as a native Rust and
GTK4 application using `gtk4-rs` and the repository's shared awesoMux-owned
Ghostty GTK shim. Preserve all shared product contracts, exact wording,
resources, screenshots, Ghostty work, and verified behavior from the Swift
attempt.

This is a fallback implementation, not permission to lower the product-parity
goal or discard evidence from the Swift track.

## Required stack

- stable Rust pinned through an explicit toolchain file
- Cargo with committed lockfile
- maintained, mutually compatible pinned versions of `gtk4`, `glib`, `gio`,
  and supporting crates
- GTK4, not GTK3
- the shared `ghostty-shim/` through its narrow C ABI
- canonical Ghostty pinned once at the repository root

Do not add CI or GitHub Actions. All Cargo, GTK, lifecycle, packaging, and
visual verification must run locally on i5GamingPC.

Do not use Electron, xterm.js, node-pty, a separate GTK overlay window, or a
new terminal renderer. Do not duplicate the Ghostty shim inside this folder.

## Rust and GTK design

- Keep GTK objects on the GLib main context.
- Use established `gtk4-rs` ownership and signal patterns.
- Keep unsafe C interop inside one thin Ghostty wrapper crate.
- Make terminal surface teardown explicit and idempotent.
- Prevent callbacks from reaching closed panes.
- Use channels with bounded ownership for background work.
- Do not make GTK objects broadly `Send` or `Sync` through unsafe wrappers.
- Prefer value types for durable product models and clear interfaces around
  platform services.
- Keep focused-pane identity authoritative for commands and context.

## Initial acceptance slice

Before broad product work, prove the same behaviors required by the Swift
track:

- two real Ghostty GTK terminal surfaces
- keyboard, Unicode input methods, mouse, clipboard, focus, scroll, and resize
- repeated create/close/recreate lifecycle stress
- safe Ghostty wakeups onto the GLib main context
- a minimal sidebar with correct focused-pane routing
- useful AT-SPI information
- launch outside Cargo's development runner
- Wayland and X11 verification
- screenshot upload under `artifacts/visual-qa/rust-gtk/`

Use the Swift track's `VIABILITY.md`, logs, and screenshots to avoid repeating
failed ideas, but independently verify Rust behavior. Do not copy workaround
code blindly across language boundaries.

## Verification

Provide track-local commands for formatting, linting, building, testing,
lifecycle stress, and packaging. The root preflight must call them when this
track is active. Use strict Clippy checks for repository-owned code and do not
format vendored sources. Do not create a remote workflow for these commands;
record local results in the implementation status.

Keep `rust-gtk/IMPLEMENTATION_STATUS.md` current if this track is activated.

When Sarah activates Rust, begin with the shared Ghostty shim and product
contract already present. Do not redo the macOS discovery phase unless the
recorded reference commit has changed.
