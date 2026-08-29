import Foundation

public struct ChromeColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        precondition(value.count == 6, "Chrome colors must use six hexadecimal digits")
        let integer = UInt64(value, radix: 16)!
        red = Double((integer >> 16) & 0xff) / 255
        green = Double((integer >> 8) & 0xff) / 255
        blue = Double(integer & 0xff) / 255
    }

    public func contrastRatio(with other: ChromeColor) -> Double {
        let values = [relativeLuminance, other.relativeLuminance].sorted(by: >)
        return (values[0] + 0.05) / (values[1] + 0.05)
    }

    private var relativeLuminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

public struct ChromeContrastRequirement: Equatable, Sendable {
    public let name: String
    public let foreground: ChromeColor
    public let background: ChromeColor
    public let minimumRatio: Double

    public init(_ name: String, foreground: String, background: String, minimumRatio: Double) {
        self.name = name
        self.foreground = ChromeColor(hex: foreground)
        self.background = ChromeColor(hex: background)
        self.minimumRatio = minimumRatio
    }

    public var measuredRatio: Double { foreground.contrastRatio(with: background) }
    public var passes: Bool { measuredRatio >= minimumRatio }
}

public enum ChromeContrastAudit {
    public static let requirements: [ChromeContrastRequirement] = [
        .init("Mocha primary text", foreground: "cdd6f4", background: "181825", minimumRatio: 4.5),
        .init("Mocha secondary text", foreground: "a6adc8", background: "181825", minimumRatio: 4.5),
        .init("Mocha compact metadata", foreground: "7f849c", background: "181825", minimumRatio: 4.5),
        .init("Mocha subtle hierarchy", foreground: "9399b2", background: "181825", minimumRatio: 4.5),
        .init("Mocha popover metadata", foreground: "9399b2", background: "252538", minimumRatio: 4.5),
        .init("Mocha control boundary", foreground: "6c7086", background: "181825", minimumRatio: 3),
        .init("Mocha focus on sidebar", foreground: "89b4fa", background: "181825", minimumRatio: 3),
        .init("Mocha focus on selected row", foreground: "89b4fa", background: "313244", minimumRatio: 3),
        .init("Mocha thinking status", foreground: "cba6f7", background: "181825", minimumRatio: 4.5),
        .init("Mocha output status", foreground: "89dceb", background: "181825", minimumRatio: 4.5),
        .init("Mocha attention status", foreground: "f38ba8", background: "181825", minimumRatio: 4.5),
        .init("Mocha Claude glyph", foreground: "fab387", background: "252538", minimumRatio: 3),
        .init("Mocha Codex glyph", foreground: "b4befe", background: "252538", minimumRatio: 3),
        .init("Mocha OpenCode glyph", foreground: "89dceb", background: "252538", minimumRatio: 3),
        .init("Mocha Pi glyph", foreground: "cba6f7", background: "252538", minimumRatio: 3),
        .init("Mocha Grok glyph", foreground: "a6e3a1", background: "252538", minimumRatio: 3),
        .init("Mocha shell glyph", foreground: "cdd6f4", background: "252538", minimumRatio: 3),
        .init("Latte primary text", foreground: "4c4f69", background: "e6e9ef", minimumRatio: 4.5),
        .init("Latte compact metadata", foreground: "5c5f77", background: "e6e9ef", minimumRatio: 4.5),
        .init("Latte popover text", foreground: "4c4f69", background: "eff1f5", minimumRatio: 4.5),
        .init("Latte control boundary", foreground: "6c6f85", background: "e6e9ef", minimumRatio: 3),
        .init("Latte focus on sidebar", foreground: "1e66f5", background: "e6e9ef", minimumRatio: 3),
        .init("Latte focus on selected row", foreground: "1e66f5", background: "ccd0da", minimumRatio: 3),
        .init("Latte selected activity title", foreground: "4c4f69", background: "ccd0da", minimumRatio: 4.5),
        .init("Latte selected activity location", foreground: "4c4f69", background: "ccd0da", minimumRatio: 4.5),
        .init("Latte selected action text", foreground: "eff1f5", background: "1859d1", minimumRatio: 4.5),
        .init("Latte thinking status", foreground: "6f20d1", background: "e6e9ef", minimumRatio: 4.5),
        .init("Latte output status", foreground: "00627d", background: "e6e9ef", minimumRatio: 4.5),
        .init("Latte attention status", foreground: "b00030", background: "e6e9ef", minimumRatio: 4.5),
        .init("Latte Claude glyph", foreground: "ad4001", background: "ccd0da", minimumRatio: 3),
        .init("Latte Codex glyph", foreground: "354fb5", background: "ccd0da", minimumRatio: 3),
        .init("Latte OpenCode glyph", foreground: "0058a8", background: "ccd0da", minimumRatio: 3),
        .init("Latte Pi glyph", foreground: "8839ef", background: "ccd0da", minimumRatio: 3),
        .init("Latte Grok glyph", foreground: "2d711f", background: "ccd0da", minimumRatio: 3),
        .init("Latte shell glyph", foreground: "4c4f69", background: "ccd0da", minimumRatio: 3),
        .init("Dark high-contrast text", foreground: "ffffff", background: "181825", minimumRatio: 7),
        .init("Light high-contrast text", foreground: "0a0a14", background: "e6e9ef", minimumRatio: 7),
        .init("Dark high-contrast secondary", foreground: "d5dcfb", background: "181825", minimumRatio: 7),
        .init("Light high-contrast secondary", foreground: "303049", background: "e6e9ef", minimumRatio: 7),
    ]
}
