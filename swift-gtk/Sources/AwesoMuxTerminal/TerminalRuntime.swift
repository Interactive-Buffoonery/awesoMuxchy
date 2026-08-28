import CAwesoMuxGhostty
import Gtk

private final class TerminalCallbackBox {
    let onFocusChanged: ((Bool) -> Void)?

    init(onFocusChanged: ((Bool) -> Void)?) {
        self.onFocusChanged = onFocusChanged
    }
}

private func terminalFocusChanged(
    userdata: UnsafeMutableRawPointer?,
    focused: Bool
) {
    guard let userdata else { return }
    let callbacks = Unmanaged<TerminalCallbackBox>.fromOpaque(userdata)
        .takeUnretainedValue()
    callbacks.onFocusChanged?(focused)
}

public final class TerminalRuntime {
    fileprivate let handle: OpaquePointer

    public init?() {
        guard let handle = amx_ghostty_app_create() else { return nil }
        self.handle = handle
    }

    deinit {
        amx_ghostty_app_destroy(handle)
    }

    public func makeSurface(
        workingDirectory: String,
        command: String? = nil,
        accessibleLabel: String,
        accessibleDescription: String,
        onFocusChanged: ((Bool) -> Void)? = nil
    ) -> TerminalSurface? {
        TerminalSurface(
            runtime: self,
            workingDirectory: workingDirectory,
            command: command,
            accessibleLabel: accessibleLabel,
            accessibleDescription: accessibleDescription,
            onFocusChanged: onFocusChanged
        )
    }
}

public final class TerminalSurface {
    private let runtime: TerminalRuntime
    private let callbackBox: TerminalCallbackBox
    private let handle: OpaquePointer
    public let widget: WidgetRef

    fileprivate init?(
        runtime: TerminalRuntime,
        workingDirectory: String,
        command: String?,
        accessibleLabel: String,
        accessibleDescription: String,
        onFocusChanged: ((Bool) -> Void)?
    ) {
        let callbackBox = TerminalCallbackBox(onFocusChanged: onFocusChanged)
        let callbacks = amx_ghostty_callbacks(
            userdata: Unmanaged.passUnretained(callbackBox).toOpaque(),
            title_changed: nil,
            close_requested: nil,
            focus_changed: terminalFocusChanged
        )
        let surface = workingDirectory.withCString { directory in
            if let command {
                return command.withCString { commandPointer in
                    amx_ghostty_surface_create(
                        runtime.handle, directory, commandPointer, callbacks
                    )
                }
            }
            return amx_ghostty_surface_create(runtime.handle, directory, nil, callbacks)
        }
        guard let surface, let rawWidget = amx_ghostty_surface_widget(surface) else {
            return nil
        }

        self.runtime = runtime
        self.callbackBox = callbackBox
        handle = surface
        widget = WidgetRef(raw: rawWidget)
        accessibleLabel.withCString { label in
            accessibleDescription.withCString { description in
                amx_ghostty_surface_set_accessible_label(surface, label, description)
            }
        }
    }

    deinit {
        amx_ghostty_surface_destroy(handle)
    }

    public func focus() {
        amx_ghostty_surface_focus(handle)
    }

    public func send(text: String) {
        text.withCString { pointer in
            amx_ghostty_surface_send_text(handle, pointer, UInt64(text.utf8.count))
        }
    }

    public var processExited: Bool {
        amx_ghostty_surface_process_exited(handle)
    }

    public var isReady: Bool {
        amx_ghostty_surface_is_ready(handle)
    }

    @discardableResult
    public func perform(bindingAction: String) -> Bool {
        bindingAction.withCString { amx_ghostty_surface_binding_action(handle, $0) }
    }

    public func requestClose() {
        amx_ghostty_surface_request_close(handle)
    }

    public func sendEnter() {
        amx_ghostty_surface_send_enter(handle)
    }
}
