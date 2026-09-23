import CAwesoMuxGhostty
import Gtk
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

private final class TerminalCallbackBox {
    let onFocusChanged: ((Bool) -> Void)?
    let onTitleChanged: ((String) -> Void)?
    let onWorkingDirectoryChanged: ((String) -> Void)?
    let onPermissionRequested: ((UInt64, TerminalPermissionKind, Int, Int) -> Void)?
    let onPermissionCancelled: ((UInt64) -> Void)?

    init(
        onFocusChanged: ((Bool) -> Void)?,
        onTitleChanged: ((String) -> Void)?,
        onWorkingDirectoryChanged: ((String) -> Void)?,
        onPermissionRequested: ((UInt64, TerminalPermissionKind, Int, Int) -> Void)?,
        onPermissionCancelled: ((UInt64) -> Void)?
    ) {
        self.onFocusChanged = onFocusChanged
        self.onTitleChanged = onTitleChanged
        self.onWorkingDirectoryChanged = onWorkingDirectoryChanged
        self.onPermissionRequested = onPermissionRequested
        self.onPermissionCancelled = onPermissionCancelled
    }
}

public enum TerminalPermissionKind {
    case clipboardWrite
    case unsafePaste
}

private func terminalPermissionRequested(
    userdata: UnsafeMutableRawPointer?, requestID: UInt64,
    kind: amx_ghostty_permission_kind, characterCount: Int, byteCount: Int
) {
    guard let userdata else { return }
    let callbacks = Unmanaged<TerminalCallbackBox>.fromOpaque(userdata).takeUnretainedValue()
    let permission: TerminalPermissionKind = kind == AMX_GHOSTTY_PERMISSION_CLIPBOARD_WRITE
        ? .clipboardWrite : .unsafePaste
    callbacks.onPermissionRequested?(requestID, permission, characterCount, byteCount)
}

private func terminalPermissionCancelled(userdata: UnsafeMutableRawPointer?, requestID: UInt64) {
    guard let userdata else { return }
    let callbacks = Unmanaged<TerminalCallbackBox>.fromOpaque(userdata).takeUnretainedValue()
    callbacks.onPermissionCancelled?(requestID)
}

private func terminalTitleChanged(userdata: UnsafeMutableRawPointer?, title: UnsafePointer<CChar>?) {
    guard let userdata, let title else { return }
    let callbacks = Unmanaged<TerminalCallbackBox>.fromOpaque(userdata).takeUnretainedValue()
    callbacks.onTitleChanged?(String(cString: title))
}

private func terminalWorkingDirectoryChanged(
    userdata: UnsafeMutableRawPointer?, workingDirectory: UnsafePointer<CChar>?
) {
    guard let userdata, let workingDirectory else { return }
    let callbacks = Unmanaged<TerminalCallbackBox>.fromOpaque(userdata).takeUnretainedValue()
    callbacks.onWorkingDirectoryChanged?(String(cString: workingDirectory))
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

    /// Select Ghostty's supported desktop-OpenGL GTK path before GTK starts.
    public static func prepareGTKEnvironment() -> Bool {
        amx_ghostty_prepare_gtk_environment()
    }

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
        environment: [String: String] = [:],
        accessibleLabel: String,
        accessibleDescription: String,
        onFocusChanged: ((Bool) -> Void)? = nil,
        onTitleChanged: ((String) -> Void)? = nil,
        onWorkingDirectoryChanged: ((String) -> Void)? = nil,
        onPermissionRequested: ((UInt64, TerminalPermissionKind, Int, Int) -> Void)? = nil,
        onPermissionCancelled: ((UInt64) -> Void)? = nil
    ) -> TerminalSurface? {
        TerminalSurface(
            runtime: self,
            workingDirectory: workingDirectory,
            command: command,
            environment: environment,
            accessibleLabel: accessibleLabel,
            accessibleDescription: accessibleDescription,
            onFocusChanged: onFocusChanged,
            onTitleChanged: onTitleChanged,
            onWorkingDirectoryChanged: onWorkingDirectoryChanged,
            onPermissionRequested: onPermissionRequested,
            onPermissionCancelled: onPermissionCancelled
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
        environment: [String: String],
        accessibleLabel: String,
        accessibleDescription: String,
        onFocusChanged: ((Bool) -> Void)?,
        onTitleChanged: ((String) -> Void)?,
        onWorkingDirectoryChanged: ((String) -> Void)?,
        onPermissionRequested: ((UInt64, TerminalPermissionKind, Int, Int) -> Void)?,
        onPermissionCancelled: ((UInt64) -> Void)?
    ) {
        let callbackBox = TerminalCallbackBox(
            onFocusChanged: onFocusChanged,
            onTitleChanged: onTitleChanged,
            onWorkingDirectoryChanged: onWorkingDirectoryChanged,
            onPermissionRequested: onPermissionRequested,
            onPermissionCancelled: onPermissionCancelled
        )
        let callbacks = amx_ghostty_callbacks(
            userdata: Unmanaged.passUnretained(callbackBox).toOpaque(),
            title_changed: terminalTitleChanged,
            working_directory_changed: terminalWorkingDirectoryChanged,
            close_requested: nil,
            focus_changed: terminalFocusChanged,
            permission_requested: terminalPermissionRequested,
            permission_cancelled: terminalPermissionCancelled
        )
        let entries = environment.sorted { $0.key < $1.key }
        let keys: [UnsafeMutablePointer<CChar>?] = entries.map { strdup($0.key) }
        let values: [UnsafeMutablePointer<CChar>?] = entries.map { strdup($0.value) }
        defer {
            keys.forEach { free($0) }
            values.forEach { free($0) }
        }
        guard keys.allSatisfy({ $0 != nil }), values.allSatisfy({ $0 != nil }) else { return nil }
        var variables: [amx_ghostty_env_var] = entries.indices.map { index in
            amx_ghostty_env_var(key: UnsafePointer(keys[index]!), value: UnsafePointer(values[index]!))
        }
        let surface = workingDirectory.withCString { directory in
            func create(_ commandPointer: UnsafePointer<CChar>?) -> OpaquePointer? {
                variables.withUnsafeMutableBufferPointer { buffer in
                    amx_ghostty_surface_create_with_environment(
                        runtime.handle, directory, commandPointer,
                        buffer.baseAddress, buffer.count, callbacks
                    )
                }
            }
            if let command { return command.withCString(create) }
            return create(nil)
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
        // The shim may cancel a pending request synchronously here. callbackBox
        // remains alive until this deinitializer returns.
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

    public var needsConfirmQuit: Bool {
        amx_ghostty_surface_needs_confirm_quit(handle)
    }

    public var hasSeenPrompt: Bool {
        amx_ghostty_surface_has_seen_prompt(handle)
    }

    public var foregroundProcessID: UInt64? {
        let value = amx_ghostty_surface_foreground_process_id(handle)
        return value == 0 ? nil : value
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

    @discardableResult
    public func resolvePermission(_ requestID: UInt64, allow: Bool) -> Bool {
        amx_ghostty_surface_resolve_permission(handle, requestID, allow)
    }

    public func sendEnter() {
        amx_ghostty_surface_send_enter(handle)
    }
}
