# awesoMux Linux GTK experiments

This private repository contains two native GTK4 implementation tracks for the
Linux edition of awesoMux:

- `swift-gtk/` is the active first implementation using Swift and SwiftGtk4.
- `rust-gtk/` is the prepared fallback using Rust and gtk4-rs.

Both tracks use the same product contract, exact wording, visual references,
resources, canonical Ghostty pin, and awesoMux-owned Ghostty GTK shim. The
shared boundary prevents a language change from discarding the difficult
terminal integration and product-parity work.

Read `AGENT_PROMPT.md` first, then the prompt inside the selected track. Start
with `swift-gtk/AGENT_PROMPT.md`. Do not work on both tracks at the same time
unless Sarah explicitly asks for a comparison.

Progress screenshots are stored under:

```text
artifacts/visual-qa/swift-gtk/
artifacts/visual-qa/rust-gtk/
```

The macOS awesoMux project is a read-only reference. Work in this repository
must never change it.
