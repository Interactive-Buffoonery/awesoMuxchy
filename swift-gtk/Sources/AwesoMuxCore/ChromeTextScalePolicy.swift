import Foundation

public enum ChromeTextScalePolicy {
    private static let baselineXftDPI = 96 * 1024

    public static func scale(xftDPI: Int, dpiScaleOverride: String? = nil) -> Double {
        let systemScale = xftDPI > 0 ? Double(xftDPI) / Double(baselineXftDPI) : 1
        let overrideScale = dpiScaleOverride.flatMap(Double.init) ?? 1
        return min(2, max(1, max(systemScale, overrideScale)))
    }

    public static func applying(to css: String, scale: Double) -> String {
        let boundedScale = min(2, max(1, scale))
        guard boundedScale > 1.001,
              let expression = try? NSRegularExpression(
                pattern: #"font-size:([0-9]+(?:\.[0-9]+)?)px"#
              )
        else { return css }

        let mutable = NSMutableString(string: css)
        let range = NSRange(location: 0, length: mutable.length)
        for match in expression.matches(in: css, range: range).reversed() {
            guard let numberRange = Range(match.range(at: 1), in: css),
                  let value = Double(css[numberRange])
            else { continue }
            let scaled = (value * boundedScale * 100).rounded() / 100
            _ = expression.replaceMatches(
                in: mutable,
                options: [],
                range: match.range,
                withTemplate: "font-size:\(scaled)px"
            )
        }
        return mutable as String
    }
}
