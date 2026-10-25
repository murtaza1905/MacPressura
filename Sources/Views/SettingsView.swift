// Sources/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: MainViewModel

    @AppStorage(SettingsKey.extractionTarget) private var extractionTarget: ExtractionTarget = .smart
    @AppStorage(SettingsKey.overwritePolicy) private var overwritePolicy: OverwritePolicy = .rename
    @AppStorage(SettingsKey.defaultFormat) private var defaultFormat: ArchiveFormat = .sevenZip
    @AppStorage(SettingsKey.defaultLevel) private var defaultLevel: CompressionLevel = .normal
    @AppStorage(SettingsKey.revealAfterExtract) private var revealAfterExtract = true
    @AppStorage(SettingsKey.revealAfterCreate) private var revealAfterCreate = true
    @AppStorage(SettingsKey.excludeMacMetadata) private var excludeMacMetadata = true
    @AppStorage(SettingsKey.encryptHeadersByDefault) private var encryptHeadersByDefault = true

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section(String(localized: "Extraction")) {
                Picker(String(localized: "Default target"), selection: $extractionTarget) {
                    ForEach(ExtractionTarget.allCases) { target in
                        Text(target.localizedName).tag(target)
                    }
                }
                Picker(String(localized: "When a file already exists"), selection: $overwritePolicy) {
                    ForEach(OverwritePolicy.allCases) { policy in
                        Text(policy.localizedName).tag(policy)
                    }
                }
                Toggle(String(localized: "Show extracted content in Finder when done"), isOn: $revealAfterExtract)
            }

            Section(String(localized: "New archives")) {
                Picker(String(localized: "Default format"), selection: $defaultFormat) {
                    ForEach(ArchiveFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                Picker(String(localized: "Default compression"), selection: $defaultLevel) {
                    ForEach(CompressionLevel.allCases) { level in
                        Text(level.localizedName).tag(level)
                    }
                }
                Toggle(String(localized: "Skip macOS metadata files by default"), isOn: $excludeMacMetadata)
                Toggle(String(localized: "Encrypt file names by default (7z, when a password is set)"), isOn: $encryptHeadersByDefault)
                Toggle(String(localized: "Show the new archive in Finder when done"), isOn: $revealAfterCreate)
            }

            Section(String(localized: "About")) {
                LabeledContent(String(localized: "MacPressura"), value: appVersion)
                LabeledContent(String(localized: "Engine"), value: model.engineBanner.isEmpty ? "7-Zip" : model.engineBanner)
                Text("Open source under the MIT license. Bundles 7-Zip (7zz) by Igor Pavlov under the LGPL. Everything runs locally; nothing leaves your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("github.com/murtaza1905/MacPressura", destination: URL(string: "https://github.com/murtaza1905/MacPressura")!)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 520)
    }
}
