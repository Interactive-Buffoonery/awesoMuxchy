import AwesoMuxTerminal
import Foundation
import Gdk
import GIO
import GLib
import Gtk

private let clipboardToken = "awesomux-clipboard-ok"
private let unicodePayload = "café e\u{301} 🚀 界"
private let reflowToken = "awesomux-reflow-ok"
private let scrollbackToken = "awesomux-scrollback-preserved"

private final class FocusRecorder {
    var focusedSurfaces: Set<Int> = []
    var focusEnterCountBySurface: [Int: Int] = [:]
    var sawExpectedTitle = false
    var sawExpectedWorkingDirectory = false
    var sawExpectedEnvironment = false
    var sawRemountedTitle = false
    var sawRemountedWorkingDirectory = false

    func record(surface: Int, focused: Bool) {
        if focused {
            focusedSurfaces.insert(surface)
            focusEnterCountBySurface[surface, default: 0] += 1
        }
    }
}

private final class IntegrationState {
    let application: Gtk.ApplicationRef
    let window: ApplicationWindowRef
    let first: TerminalSurface
    var second: TerminalSurface!
    let panes: PanedRef
    let focusRecorder: FocusRecorder
    let unicodeFile: URL
    let reflowFile: URL
    var failed = false
    var failureReason = "none"
    var resizeReflowVerificationAttempts = 0
    var remountChecks = 0
    var shellProcessID: UInt64?
    var remountCompletionAttempts = 0
    var remountFocusTransferVerified = false
    let skipClipboard = ProcessInfo.processInfo.environment[
        "AWESOMUX_TERMINAL_INTEGRATION_NO_CLIPBOARD"
    ] == "1"

    init(
        application: Gtk.ApplicationRef,
        window: ApplicationWindowRef,
        first: TerminalSurface,
        second: TerminalSurface,
        panes: PanedRef,
        focusRecorder: FocusRecorder
    ) {
        self.application = application
        self.window = window
        self.first = first
        self.second = second
        self.panes = panes
        self.focusRecorder = focusRecorder
        unicodeFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("awesomux-terminal-unicode-\(UUID().uuidString)")
        reflowFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("awesomux-terminal-reflow-\(UUID().uuidString)")
    }

    func begin() -> Bool {
        window.setDefaultSize(width: 1100, height: 720)
        guard first.isReady, second.isReady else {
            fail(reason: "terminal surface not ready")
            return false
        }
        first.focus()
        if skipClipboard {
            first.send(text: "exit")
        } else {
            guard let clipboard = first.widget.getClipboard() else {
                fail(reason: "clipboard unavailable")
                return false
            }
            clipboard.set(text: "exit")
            guard first.perform(bindingAction: "paste_from_clipboard") else {
                fail(reason: "paste action unavailable")
                return false
            }
        }
        timeout(add: 500) { [weak self] in
            self?.first.sendEnter()
            return false
        }

        second.focus()
        let quotedFile = unicodeFile.path.replacingOccurrences(of: "'", with: "'\\''")
        second.send(text: "printf '%s' 'café é 🚀 界' > '\(quotedFile)'")
        second.sendEnter()
        second.send(text: "printf '\\033]2;awesomux-title-ok\\a\\033]7;file://localhost/tmp/awesomux-cwd-ok\\a'")
        second.sendEnter()
        second.send(text: "if [ \"$AWESOMUX_AGENT_EVENT_PROTOCOL\" = 'awesomux-agent-v1' ] && [ \"$AWESOMUX_SESSION_ID\" = 'session-test' ] && [ \"$AWESOMUX_PANE_ID\" = 'pane-test' ] && [ \"$AWESOMUX_AGENT_EVENT_FILE\" = '/tmp/awesomux-event-test' ]; then printf '\\033]2;awesomux-environment-ok\\a'; fi")
        second.sendEnter()
        return false
    }

    func verifyReadAndRequestWrite() -> Bool {
        guard focusRecorder.focusedSurfaces == [0, 1] else {
            fail(reason: "focus callbacks did not identify both terminal surfaces")
            return false
        }
        guard first.processExited else {
            fail(reason: "clipboard paste did not exit first terminal")
            return false
        }
        guard !second.processExited else {
            fail(reason: "second terminal exited unexpectedly")
            return false
        }
        guard let data = try? Data(contentsOf: unicodeFile) else {
            fail(reason: "Unicode input result unavailable")
            return false
        }
        guard String(data: data, encoding: .utf8) == unicodePayload else {
            fail(reason: "Unicode input mismatch")
            return false
        }
        guard focusRecorder.sawExpectedTitle else {
            fail(reason: "title callback mismatch")
            return false
        }
        guard focusRecorder.sawExpectedWorkingDirectory else {
            fail(reason: "working-directory callback mismatch")
            return false
        }
        guard focusRecorder.sawExpectedEnvironment else {
            fail(reason: "surface environment mismatch")
            return false
        }

        guard let shellProcessID = second.foregroundProcessID else {
            fail(reason: "foreground shell process unavailable")
            return false
        }
        self.shellProcessID = shellProcessID
        guard second.hasSeenPrompt else {
            fail(reason: "semantic prompt marker was not observed")
            return false
        }
        guard !second.needsConfirmQuit else {
            fail(reason: "observed idle prompt unexpectedly requires confirmation")
            return false
        }
        beginResizeReflowStress(shellProcessID: shellProcessID)
        return false
    }

    func beginResizeReflowStress(shellProcessID: UInt64) {
        let quotedFile = reflowFile.path.replacingOccurrences(of: "'", with: "'\\''")
        let payload = "awesomux reflow café é 🚀 界 — 0123456789 0123456789 0123456789"
        let command = [
            "printf '%s\\n' '\(scrollbackToken)';",
            "i=0; while [ $i -lt 120 ]; do",
            "printf '%s\\n' '\(payload)'; sleep 0.01; i=$((i+1)); done;",
            "printf '%s' '\(reflowToken)' > '\(quotedFile)'",
        ].joined(separator: " ")
        second.send(text: command)
        second.sendEnter()

        var step = 0
        timeout(add: 15) { [weak self] in
            guard let self else { return false }
            let extent = self.panes.getWidth()
            guard extent > 400 else {
                self.fail(reason: "split allocation unavailable during resize stress")
                return false
            }
            let span = max(extent - 360, 1)
            self.panes.set(position: 180 + ((step * 37) % span))
            step += 1
            if step < 80 { return true }
            self.panes.set(position: extent / 2)
            timeout(add: 500) { [weak self] in
                self?.verifyResizeReflowStress(shellProcessID: shellProcessID)
                return false
            }
            return false
        }
    }

    func verifyResizeReflowStress(shellProcessID: UInt64) {
        guard second.isReady, !second.processExited else {
            fail(reason: "terminal surface failed during resize reflow stress")
            return
        }
        guard let data = try? Data(contentsOf: reflowFile),
              String(data: data, encoding: .utf8) == reflowToken else {
            resizeReflowVerificationAttempts += 1
            if resizeReflowVerificationAttempts < 50 {
                timeout(add: 100) { [weak self] in
                    self?.verifyResizeReflowStress(shellProcessID: shellProcessID)
                    return false
                }
                return
            }
            fail(reason: "Unicode resize reflow command did not complete")
            return
        }
        second.focus()
        second.send(text: "sleep 8")
        second.sendEnter()
        timeout(add: 250) { [weak self] in
            self?.verifyLayoutRemount(shellProcessID: shellProcessID)
            return false
        }
    }

    func verifyLayoutRemount(shellProcessID: UInt64) {
        guard let jobProcessID = second.foregroundProcessID,
              jobProcessID != shellProcessID else {
            fail(reason: "long-running job PID unavailable before layout remount")
            return
        }
        // GTK unparenting unrealizes the GL area even while the Swift surface
        // object is retained. This is the same boundary reached by split,
        // sibling close, and grow/shrink layout remounts.
        let focusCountBefore = focusRecorder.focusEnterCountBySurface[1, default: 0]
        let closeRiskBefore = second.needsConfirmQuit
        let promptSeenBefore = second.hasSeenPrompt
        for _ in 0..<8 {
            _ = second.widget.ref()
            panes.setEnd(child: nil)
            guard second.isReady,
                  second.foregroundProcessID == jobProcessID else {
                second.widget.unref()
                fail(reason: "terminal core ended when GTK unrealized the pane")
                return
            }
            panes.setEnd(child: second.widget)
            second.widget.unref()
            guard second.isReady,
                  second.foregroundProcessID == jobProcessID,
                  !second.processExited else {
                fail(reason: "terminal process changed during layout remount")
                return
            }
            remountChecks += 1
        }
        if ProcessInfo.processInfo.environment[
            "AWESOMUX_GHOSTTY_TEST_GL_UNREALIZE_FAIL_ONCE"
        ] == "1", second.displayRecoveryCount != 1 {
            fail(reason: "deferred GL cleanup did not recover exactly once")
            return
        }
        let windowWasActive = window.isActive
        first.focus()
        let siblingTookFocus = windowWasActive && first.widget.hasFocus()
        timeout(add: 100) { [weak self] in
            self?.second.focus()
            timeout(add: 100) { [weak self] in
                self?.verifyRemountFocus(shellProcessID: shellProcessID,
                                         focusCountBefore: focusCountBefore,
                                         closeRiskBefore: closeRiskBefore,
                                         promptSeenBefore: promptSeenBefore,
                                         siblingTookFocus: siblingTookFocus)
                return false
            }
            return false
        }
    }

    func verifyRemountFocus(shellProcessID: UInt64, focusCountBefore: Int,
                            closeRiskBefore: Bool, promptSeenBefore: Bool,
                            siblingTookFocus: Bool) {
        if siblingTookFocus && window.isActive {
            guard second.widget.hasFocus(),
                  focusRecorder.focusEnterCountBySurface[1, default: 0] > focusCountBefore else {
                fail(reason: "focus callback lost after proven layout-remount focus transfer")
                return
            }
            remountFocusTransferVerified = true
        }
        verifyCloseRisk(shellProcessID: shellProcessID,
                        closeRiskBefore: closeRiskBefore,
                        promptSeenBefore: promptSeenBefore)
    }

    func verifyCloseRisk(shellProcessID: UInt64, closeRiskBefore: Bool,
                         promptSeenBefore: Bool) {
        guard let activeProcessID = second.foregroundProcessID,
              activeProcessID != shellProcessID
        else {
            fail(reason: "foreground process did not change for running command")
            return
        }
        guard second.needsConfirmQuit == closeRiskBefore else {
            fail(reason: "close-risk signal changed during layout remount")
            return
        }
        guard second.hasSeenPrompt == promptSeenBefore else {
            fail(reason: "semantic prompt observation was lost")
            return
        }
        timeout(add: 500) { [weak self] in
            self?.requestClipboardWrite()
            return false
        }
    }

    func requestClipboardWrite() {
        guard second.foregroundProcessID == shellProcessID else {
            remountCompletionAttempts += 1
            if remountCompletionAttempts < 120 {
                timeout(add: 100) { [weak self] in
                    self?.requestClipboardWrite()
                    return false
                }
                return
            }
            fail(reason: "shell PID changed after layout remount")
            return
        }
        guard second.containsText(scrollbackToken) else {
            fail(reason: "scrollback changed after layout remount")
            return
        }
        second.send(text: "printf '\\033]2;awesomux-remount-title-ok\\a\\033]7;file://localhost/tmp/awesomux-remount-cwd-ok\\a'")
        second.sendEnter()
        timeout(add: 500) { [weak self] in
            self?.verifyRemountedCallbacksAndRequestClipboardWrite()
            return false
        }
    }

    func verifyRemountedCallbacksAndRequestClipboardWrite() {
        guard focusRecorder.sawRemountedTitle,
              focusRecorder.sawRemountedWorkingDirectory else {
            fail(reason: "title or working-directory callback lost after layout remount")
            return
        }
        if skipClipboard {
            complete(clipboardText: nil)
            return
        }
        let encoded = Data(clipboardToken.utf8).base64EncodedString()
        second.send(text: "printf '\\033]52;c;\(encoded)\\a'")
        second.sendEnter()
        timeout(add: 500) { [weak self] in
            self?.readClipboard()
            return false
        }
    }

    func readClipboard() {
        guard let clipboard = second.widget.getClipboard() else {
            fail(reason: "clipboard unavailable after write")
            return
        }
        clipboard.readTextAsync(
            callback: { _, result, userdata in
                guard let result, let userdata else { return }
                let state = Unmanaged<IntegrationState>
                    .fromOpaque(userdata).takeUnretainedValue()
                guard let clipboard = state.second.widget.getClipboard() else {
                    state.fail(reason: "clipboard unavailable in callback")
                    return
                }
                let text = try? clipboard.readTextFinish(
                    result: GIO.AsyncResultRef(result)
                )
                state.complete(clipboardText: text ?? nil)
            },
            userData: Unmanaged.passUnretained(self).toOpaque()
        )
    }

    func complete(clipboardText: String?) {
        guard remountChecks == 8,
              skipClipboard || clipboardText == clipboardToken else {
            fail(reason: "remount count or clipboard write mismatch")
            return
        }
        guard let shellProcessID else {
            fail(reason: "shell PID unavailable for detached close")
            return
        }
        try? FileManager.default.removeItem(at: unicodeFile)
        try? FileManager.default.removeItem(at: reflowFile)
        // Release a still-live detached surface with no usable old GL context.
        // Final teardown abandons stale GPU handles while retiring its PTY.
        panes.setEnd(child: nil)
        second = nil
        verifyDetachedClose(processID: shellProcessID, attempt: 0)
    }

    func verifyDetachedClose(processID: UInt64, attempt: Int) {
        if !FileManager.default.fileExists(atPath: "/proc/\(processID)") {
            application.quit()
            return
        }
        guard attempt < 50 else {
            fail(reason: "detached surface process survived explicit release")
            return
        }
        timeout(add: 100) { [weak self] in
            self?.verifyDetachedClose(processID: processID, attempt: attempt + 1)
            return false
        }
    }

    func fail(reason: String) {
        failed = true
        failureReason = reason
        try? FileManager.default.removeItem(at: unicodeFile)
        try? FileManager.default.removeItem(at: reflowFile)
        application.quit()
    }
}

nonisolated(unsafe) private var retainedIntegrationState: IntegrationState?

private func runIntegration(application: Gtk.ApplicationRef) {
    guard let runtime = TerminalRuntime() else {
        application.quit()
        return
    }
    let directory = FileManager.default.currentDirectoryPath
    let focusRecorder = FocusRecorder()
    guard let first = runtime.makeSurface(
        workingDirectory: directory,
        accessibleLabel: "Clipboard read terminal",
        accessibleDescription: "Terminal used to verify clipboard paste and exit",
        onFocusChanged: { focusRecorder.record(surface: 0, focused: $0) }
    ), let second = runtime.makeSurface(
        workingDirectory: directory,
        environment: [
            "AWESOMUX_AGENT_EVENT_PROTOCOL": "awesomux-agent-v1",
            "AWESOMUX_SESSION_ID": "session-test",
            "AWESOMUX_PANE_ID": "pane-test",
            "AWESOMUX_AGENT_EVENT_FILE": "/tmp/awesomux-event-test",
        ],
        accessibleLabel: "Clipboard write terminal",
        accessibleDescription: "Terminal used to verify Unicode input and clipboard write",
        onFocusChanged: { focusRecorder.record(surface: 1, focused: $0) },
        onTitleChanged: {
            if $0 == "awesomux-title-ok" { focusRecorder.sawExpectedTitle = true }
            if $0 == "awesomux-environment-ok" { focusRecorder.sawExpectedEnvironment = true }
            if $0 == "awesomux-remount-title-ok" { focusRecorder.sawRemountedTitle = true }
        },
        onWorkingDirectoryChanged: {
            if $0 == "/tmp/awesomux-cwd-ok" { focusRecorder.sawExpectedWorkingDirectory = true }
            if $0 == "/tmp/awesomux-remount-cwd-ok" {
                focusRecorder.sawRemountedWorkingDirectory = true
            }
        }
    ) else {
        application.quit()
        return
    }

    let window = ApplicationWindowRef(application: application)
    window.title = "awesoMux terminal integration"
    window.setDefaultSize(width: 900, height: 600)
    let panes = PanedRef(orientation: .horizontal)
    panes.setStart(child: first.widget)
    panes.setEnd(child: second.widget)
    window.set(child: panes)
    window.present()

    let state = IntegrationState(
        application: application,
        window: window,
        first: first,
        second: second,
        panes: panes,
        focusRecorder: focusRecorder
    )
    retainedIntegrationState = state
    timeout(add: 1_500) { [weak state] in state?.begin() ?? false }
    timeout(add: 3_500) { [weak state] in state?.verifyReadAndRequestWrite() ?? false }
}

guard TerminalRuntime.prepareGTKEnvironment() else {
    fatalError("Could not prepare GTK for Ghostty rendering")
}
let status = Application.run(
    id: "com.interactivebuffoonery.awesomux.terminal-integration",
    arguments: CommandLine.arguments,
    activationHandler: runIntegration
)
let failed = retainedIntegrationState?.failed ?? true
let failureReason = retainedIntegrationState?.failureReason ?? "state unavailable"
let remountFocusCoverage = retainedIntegrationState?.remountFocusTransferVerified == true
    ? "post-remount focus transfer verified"
    : "post-remount focus transfer skipped (window focus unavailable)"
retainedIntegrationState = nil

guard status != nil, !failed else {
    print("terminal integration: failed (\(failureReason))")
    exit(1)
}
let clipboardCoverage = ProcessInfo.processInfo.environment[
    "AWESOMUX_TERMINAL_INTEGRATION_NO_CLIPBOARD"
] == "1" ? "clipboard skipped" : "clipboard"
print("terminal integration: passed input, Unicode, initial focus callbacks, \(remountFocusCoverage), rapid reflow resize, \(clipboardCoverage), environment, title/cwd callbacks, observed-prompt close-risk signals, pane independence, eight live-process remounts, and detached process release")
