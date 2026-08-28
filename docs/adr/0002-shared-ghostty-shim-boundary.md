# 0002 — One awesoMux-owned Ghostty GTK shim

- Status: Accepted
- Date: 2026-08-28
- Deciders: Sarah (repository prompt)

## Context

awesoMux requires the full Ghostty runtime and renderer on Linux. Canonical
Ghostty's embedded C API does not presently expose a supported Linux GTK host,
and substituting `libghostty-vt` plus another renderer would change the product.

## Decision

Pin canonical MIT Ghostty at the repository root and expose one narrow,
language-neutral C ABI from `ghostty-shim/`. The shim owns GTK/GL realization,
input, IME, clipboard, wakeups, actions, size/scale, and teardown. Applications
receive opaque awesoMux handles, never raw Ghostty or GTK ownership.

Any unavoidable Ghostty change is an awesoMux-owned patch applied to a staged
build copy. The submodule remains clean.

## Consequences

Swift lifecycle safety can be evaluated without tying verified renderer work to
Swift. The ABI and patch series require dedicated lifecycle, pin-apply, and
source-license tests.
