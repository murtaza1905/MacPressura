// Sources/App/AboutPanel.swift
import AppKit

/// Shows the standard macOS About window with the app's credits.
/// Version, build number and copyright are read from Info.plist by AppKit.
enum AboutPanel {

    static let author = "Murat Onurcu"
    static let email = "muratonurcu@outlook.com"
    static let repository = URL(string: "https://github.com/murtaza1905/MacPressura")!
    static let sevenZipSite = URL(string: "https://7-zip.org")!

    static var versionString: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "–"
        let build = info["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    @MainActor
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits()])
    }

    private static func credits() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 3

        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let secondary: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]

        let text = NSMutableAttributedString()

        func line(_ string: String, attributes: [NSAttributedString.Key: Any], link: URL? = nil) {
            var attrs = attributes
            if let link { attrs[.link] = link }
            text.append(NSAttributedString(string: string + "\n", attributes: attrs))
        }

        line(String(localized: "Free, open-source archive utility for macOS."), attributes: secondary)
        line("\n" + String(localized: "Developer") + ": " + author, attributes: base)
        line(email, attributes: base, link: URL(string: "mailto:\(email)"))
        line(String(localized: "Source code and issues on GitHub"), attributes: base, link: repository)
        line("\n" + String(localized: "Open source under the MIT License."), attributes: secondary)
        line(String(localized: "Archive engine: 7-Zip (7zz) by Igor Pavlov, GNU LGPL with unRAR restriction."),
             attributes: secondary, link: sevenZipSite)
        return text
    }
}
