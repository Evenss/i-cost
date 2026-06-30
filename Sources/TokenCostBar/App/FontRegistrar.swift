import CoreText
import Foundation

enum FontRegistrar {
    static func registerBundledFonts() {
        let resourceURLs = [
            Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [],
            Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        ]
        .flatMap { $0 }

        var seen = Set<URL>()
        for url in resourceURLs where seen.insert(url).inserted {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
