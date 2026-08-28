import AwesoMuxTerminal
import Foundation
import Gdk
import GIO
import GLib
import Gtk

private let clipboardToken = "awesomux-clipboard-ok"
private let unicodePayload = "café e\u{301} 🚀 界"

private final class FocusRecorder {
    var focusedSurfaces: Set<Int> = []

    func record(surface: Int, focused: Bool) {
        if focused { focusedSurfaces.insert(surface) }
    }
}

private final class IntegrationState {
    let application: Gtk.ApplicationRef
    let window: ApplicationWindowRef
    let first: TerminalSurface
    let second: TerminalSurface
    let focusRecorder: FocusRecorder
    let unicodeFile: URL
    var failed = false
    var failureReason = "none"

    init(
        application: Gtk.ApplicationRef,
        window: ApplicationWindowRef,
        first: TerminalSurface,
        second: TerminalSurface,
        focusRecorder: FocusRecorder
    ) {
        self.application = application
        self.window = window
        self.first = first
        self.second = second
        self.focusRecorder = focusRecorder
        unicodeFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("awesomux-terminal-unicode-\(UUID().uuidString)")
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

        let encoded = Data(clipboardToken.utf8).base64EncodedString()
        second.send(text: "printf '\\033]52;c;\(encoded)\\a'")
        second.sendEnter()
        timeout(add: 500) { [weak self] in
            self?.readClipboard()
            return false
        }
        return false
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
        second.requestClose()
        application.quit()
    }

    func fail(reason: String) {
        failed = true
        failureReason = reason
        try? FileManager.default.removeItem(at: unicodeFile)
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
        accessibleLabel: "Clipboard write terminal",
        accessibleDescription: "Terminal used to verify Unicode input and clipboard write",
        onFocusChanged: { focusRecorder.record(surface: 1, focused: $0) }
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
        focusRecorder: focusRecorder
    )
    retainedIntegrationState = state
    timeout(add: 1_500) { [weak state] in state?.begin() ?? false }
    timeout(add: 3_500) { [weak state] in state?.verifyReadAndRequestWrite() ?? false }
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
print("terminal integration: passed input, Unicode, focus, resize, clipboard, and pane independence")
