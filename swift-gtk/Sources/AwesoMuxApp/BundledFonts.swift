import CFontconfig
import Foundation

enum BundledFonts {
    private static let names = ["Geist-Regular", "Geist-Medium", "Geist-SemiBold", "Geist-Bold"]
    private static let registrationSucceeded: Bool = {
        guard let config = FcConfigGetCurrent() else { return false }
        var succeeded = true
        for name in names {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else {
                succeeded = false; continue
            }
            let added = url.path.withCString { path in
                FcConfigAppFontAddFile(config, UnsafeRawPointer(path).assumingMemoryBound(to: FcChar8.self)) != 0
            }
            succeeded = succeeded && added
        }
        if succeeded { succeeded = FcConfigBuildFonts(config) != 0 }
        return succeeded
    }()

    @discardableResult static func register() -> Bool { registrationSucceeded }
}
