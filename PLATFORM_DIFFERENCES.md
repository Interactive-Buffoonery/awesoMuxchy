# Platform differences

This register starts empty of approved product differences. Toolkit mechanics
do not count as user-visible differences.

| Surface | macOS behavior | Linux behavior | Reason | User effect | Status |
| --- | --- | --- | --- | --- | --- |
| Shortcut modifier labels | Uses Command/Option glyphs and macOS menu conventions. | GTK accelerators must map the same command model to Linux Control/Alt conventions while displaying platform-correct labels. | Linux keyboards and GTK do not provide the Command modifier. | Muscle-memory differs only where the physical platform requires it; action names and catalog IDs remain identical. | proposed; verify with Sarah during shortcut pass |
| Notifications/settings links | Uses `UNUserNotificationCenter` and macOS System Settings deep links. | Will use the freedesktop notification portal/service and desktop-specific settings route when available. | macOS frameworks are unavailable. | Permission/remediation UI may open a different system panel; policy and wording stay as close as the platform permits. | not started |
| Update distribution | Developer ID, notarized DMG, Sparkle, Homebrew cask. | Native Linux packaging/desktop integration; update mechanism undecided. | Apple signing and Sparkle bundle flow are macOS-specific. | Installation/update mechanics differ; in-app product behavior must not. | not started; decision required in packaging phase |
| Accessibility API | VoiceOver/AppKit accessibility. | AT-SPI via GTK4 accessible roles, names, descriptions, relations, and state. | Platform accessibility stacks differ. | Equivalent keyboard and screen-reader outcomes are required, not API identity. | vertical-slice labels/buttons implemented; full Orca pass pending |
| Terminal display backend on the current development machine | AppKit/Metal. | GTK currently runs through X11/GLX on XWayland, even in the COSMIC Wayland session. Native GTK Wayland cannot create the required desktop OpenGL context on the NVIDIA GTX 1080 Ti stack. | Reproduced with both terminal surfaces after explicitly requesting GTK's desktop GL API; the same shim passes under GLX. This is a GTK/driver path constraint, not a Swift limitation. | The terminal works, but native Wayland scaling/input behavior cannot yet be claimed and XWayland adds an integration layer. | temporary constraint; investigate and remove before release |

No difference is accepted merely because GTK defaults differ visually.
