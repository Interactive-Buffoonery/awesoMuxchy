import AwesoMuxTerminal
import Foundation
import Gdk
import GIO
import GLib
import Gtk

private let clipboardToken = "awesomux-clipboard-ok"
private let unicodePayload = "café e\u{301} 🚀 界"
private let reflowToken = "awesomux-reflow-ok"

private final class FocusRecorder {
    var focusedSurfaces: Set<Int> = []
    var sawExpectedTitle = false
    var sawExpectedWorkingDirectory = false
    var sawExpectedEnvironment = false

    func record(surface: Int, focused: Bool) {
        if focused { focusedSurfaces.insert(surface) }
    }
}

private final class IntegrationState {
    let application: Gtk.ApplicationRef
    let window: ApplicationWindowRef
    let first: TerminalSurface
    let second: TerminalSurface
    let panes: PanedRef
    let focusRecorder: FocusRecorder
    let unicodeFile: URL
    let reflowFile: URL
    var failed = false
    var failureReason = "none"
    var resizeReflowVerificationAttempts = 0

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
        guard let clipboard = first.widget.getClipboard() else {
            fail(reason: "clipboard unavailable")
            return false
        }
        clipboard.set(text: "exit")
        guard first.perform(bindingAction: "paste_from_clipboard") else {
            fail(reason: "paste action unavailable")
            return false
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
        second.send(text: "sleep 2")
        second.sendEnter()
        timeout(add: 250) { [weak self] in
            self?.verifyCloseRisk(shellProcessID: shellProcessID)
            return false
        }
    }

    func verifyCloseRisk(shellProcessID: UInt64) {
        guard let activeProcessID = second.foregroundProcessID,
              activeProcessID != shellProcessID
        else {
            fail(reason: "foreground process did not change for running command")
            return
        }
        guard second.needsConfirmQuit else {
            fail(reason: "running command did not require close confirmation")
            return
        }
        guard second.hasSeenPrompt else {
            fail(reason: "semantic prompt observation was lost")
            return
        }
        timeout(add: 2_100) { [weak self] in
            self?.requestClipboardWrite()
            return false
        }
    }

    func requestClipboardWrite() {
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
        guard clipboardText == clipboardToken else {
            fail(reason: "clipboard write mismatch")
            return
        }
        try? FileManager.default.removeItem(at: unicodeFile)
        try? FileManager.default.removeItem(at: reflowFile)
        second.requestClose()
        application.quit()
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
        },
        onWorkingDirectoryChanged: {
            if $0 == "/tmp/awesomux-cwd-ok" { focusRecorder.sawExpectedWorkingDirectory = true }
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
retainedIntegrationState = nil

guard status != nil, !failed else {
    print("terminal integration: failed (\(failureReason))")
    exit(1)
}
print("terminal integration: passed input, Unicode, focus, rapid reflow resize, clipboard, environment, title/cwd callbacks, observed-prompt close-risk signals, and pane independence")
