# Platform differences

## Keyboard modifiers

Linux uses Control for the macOS Command shortcut layer and Alt for Option.
Shortcuts that use both macOS Control and Command map to Super+Control so the
chord stays distinct. The shared Linux command catalog owns this translation;
Ghostty keybindings are not a parallel application-command route.

This register starts empty of approved product differences. Toolkit mechanics
do not count as user-visible differences.

| Surface | macOS behavior | Linux behavior | Reason | User effect | Status |
| --- | --- | --- | --- | --- | --- |
| Shortcut modifier labels | Uses Command/Option glyphs and macOS menu conventions. | GTK accelerators must map the same command model to Linux Control/Alt conventions while displaying platform-correct labels. | Linux keyboards and GTK do not provide the Command modifier. | Muscle-memory differs only where the physical platform requires it; action names and catalog IDs remain identical. | proposed; verify with Sarah during shortcut pass |
| Notifications/settings links | Uses `UNUserNotificationCenter` and macOS System Settings deep links. | Will use the freedesktop notification portal/service and desktop-specific settings route when available. | macOS frameworks are unavailable. | Permission/remediation UI may open a different system panel; policy and wording stay as close as the platform permits. | not started |
| Update distribution | Developer ID, notarized DMG, Sparkle, Homebrew cask. | Native Linux packaging/desktop integration; update mechanism undecided. | Apple signing and Sparkle bundle flow are macOS-specific. | Installation/update mechanics differ; in-app product behavior must not. | not started; decision required in packaging phase |
| Accessibility API | VoiceOver/AppKit accessibility. | AT-SPI via GTK4 accessible roles, names, descriptions, relations, and state. | Platform accessibility stacks differ. | Equivalent keyboard and screen-reader outcomes are required, not API identity. | vertical-slice labels/buttons implemented; full Orca pass pending |
| Footer file/editor opening | Finder and Launch Services discover app bundles and reveal the focused path. | Files/default file handler uses GIO; supported editors are discovered as executable commands on `PATH`. | Linux desktop applications do not have macOS bundle identifiers or Finder. | The same path can be opened, revealed, or copied; available editor names depend on installed Linux command launchers. | implemented; desktop matrix still needs testing |
| Footer font and status glyph outlines | Uses the macOS system monospaced face and SF Symbols. | Uses Noto Sans Mono with DejaVu Sans Mono/generic fallbacks and portable GTK/Unicode status glyphs at the same measured sizes and weights. | Apple's system fonts and SF Symbols are not redistributable Linux dependencies. | Text density, hierarchy, spacing, color, and meaning match; individual letter and icon outlines vary slightly with the installed Linux font stack. | implemented and visually inspected on the target Pop!_OS system |
| Terminal display backend on the current development machine | AppKit/Metal. | GTK currently runs through X11/GLX on XWayland, even in the COSMIC Wayland session. Native GTK Wayland cannot create the required desktop OpenGL context on the NVIDIA GTX 1080 Ti stack. | Reproduced with both terminal surfaces after explicitly requesting GTK's desktop GL API; the same shim passes under GLX. This is a GTK/driver path constraint, not a Swift limitation. | The terminal works, but native Wayland scaling/input behavior cannot yet be claimed and XWayland adds an integration layer. | temporary constraint; investigate and remove before release |

No difference is accepted merely because GTK defaults differ visually.
