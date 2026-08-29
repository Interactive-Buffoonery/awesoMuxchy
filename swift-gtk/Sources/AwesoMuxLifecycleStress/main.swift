import AwesoMuxTerminal
import Foundation
import GLib
import Gtk

private final class StressState {
    let application: ApplicationRef
    let runtime: TerminalRuntime
    let container: BoxRef
    var surfaces: [TerminalSurface] = []
    var completedCycles = 0
    var failed = false

    init(application: ApplicationRef, runtime: TerminalRuntime, container: BoxRef) {
        self.application = application
        self.runtime = runtime
        self.container = container
    }

    func replaceBusySurfaces() -> Bool {
        if !surfaces.isEmpty && !surfaces.allSatisfy(\.isReady) {
            failed = true
            application.quit()
            return false
        }
        for surface in surfaces {
            container.remove(child: surface.widget)
        }
        surfaces.removeAll()

        if completedCycles == 100 {
            application.quit()
            return false
        }

        let directory = FileManager.default.currentDirectoryPath
        for index in 1...2 {
            guard let surface = runtime.makeSurface(
                workingDirectory: directory,
                command: "/usr/bin/yes",
                accessibleLabel: "Stress terminal \(index)",
                accessibleDescription: "Lifecycle stress-test terminal surface"
            ) else {
                failed = true
                application.quit()
                return false
            }
            surfaces.append(surface)
            container.append(child: surface.widget)
        }
        completedCycles += 1
        return true
    }
}

nonisolated(unsafe) private var retainedStressState: StressState?

private func runStress(application: ApplicationRef) {
    guard let runtime = TerminalRuntime() else {
        application.quit()
        return
    }
    let window = ApplicationWindowRef(application: application)
    window.title = "awesoMux lifecycle stress"
    window.setDefaultSize(width: 800, height: 500)
    let container = BoxRef(orientation: .horizontal, spacing: 1)
    window.set(child: container)
    window.present()

    let state = StressState(application: application, runtime: runtime, container: container)
    retainedStressState = state
    _ = state.replaceBusySurfaces()
    timeout(add: 50) { [weak state] in
        state?.replaceBusySurfaces() ?? false
    }
}

guard TerminalRuntime.prepareGTKEnvironment() else {
    fatalError("Could not prepare GTK for Ghostty rendering")
}
let status = Application.run(
    id: "com.interactivebuffoonery.awesomux.lifecycle-stress",
    arguments: CommandLine.arguments,
    activationHandler: runStress
)
let failed = retainedStressState?.failed ?? true
let cycles = retainedStressState?.completedCycles ?? 0
retainedStressState = nil

guard status != nil, !failed, cycles == 100 else {
    print("lifecycle stress: failed")
    exit(1)
}
print("lifecycle stress: passed 100 two-surface cycles")
