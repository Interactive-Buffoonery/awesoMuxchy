import Testing
@testable import AwesoMuxCore

@Test func chromeTextScaleUsesGTKXftDPIAndDefensiveBounds() {
    #expect(ChromeTextScalePolicy.scale(xftDPI: -1) == 1)
    #expect(ChromeTextScalePolicy.scale(xftDPI: 96 * 1024) == 1)
    #expect(ChromeTextScalePolicy.scale(xftDPI: 144 * 1024) == 1.5)
    #expect(ChromeTextScalePolicy.scale(xftDPI: 400 * 1024) == 2)
    #expect(ChromeTextScalePolicy.scale(xftDPI: -1, dpiScaleOverride: "1.5") == 1.5)
    #expect(ChromeTextScalePolicy.scale(xftDPI: -1, dpiScaleOverride: "invalid") == 1)
    #expect(ChromeTextScalePolicy.scale(xftDPI: -1, dpiScaleOverride: "0.625") == 1)
}

@Test func chromeTextScaleOnlyRewritesDeclaredFontSizes() {
    let css = ".row{font-size:12px;min-height:48px}.meta{font-size:9.5px}"
    #expect(
        ChromeTextScalePolicy.applying(to: css, scale: 1.5)
            == ".row{font-size:18.0px;min-height:48px}.meta{font-size:14.25px}"
    )
    #expect(ChromeTextScalePolicy.applying(to: css, scale: 1) == css)
}
