import CoreText
import Foundation

enum AppFontRegistry {
    static let primaryFontName = "Pretendard Variable"

    static func registerBundledFonts() {
        registerFontResource(named: "PretendardVariable", extension: "woff2")
    }

    private static func registerFontResource(named name: String, extension ext: String) {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            return
        }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        _ = error?.takeRetainedValue()
    }
}
