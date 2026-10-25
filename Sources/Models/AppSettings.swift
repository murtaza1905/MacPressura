// Sources/Models/AppSettings.swift
import Foundation
import SwiftUI

/// User preferences, backed by UserDefaults so SwiftUI views can bind to them with @AppStorage.
enum SettingsKey {
    static let extractionTarget = "extractionTarget"
    static let overwritePolicy = "overwritePolicy"
    static let defaultFormat = "defaultFormat"
    static let defaultLevel = "defaultLevel"
    static let revealAfterExtract = "revealAfterExtract"
    static let revealAfterCreate = "revealAfterCreate"
    static let excludeMacMetadata = "excludeMacMetadata"
    static let encryptHeadersByDefault = "encryptHeadersByDefault"
}

/// Snapshot of the preferences for non-view code.
struct AppSettings {
    var extractionTarget: ExtractionTarget
    var overwritePolicy: OverwritePolicy
    var defaultFormat: ArchiveFormat
    var defaultLevel: CompressionLevel
    var revealAfterExtract: Bool
    var revealAfterCreate: Bool
    var excludeMacMetadata: Bool
    var encryptHeadersByDefault: Bool

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.extractionTarget: ExtractionTarget.smart.rawValue,
            SettingsKey.overwritePolicy: OverwritePolicy.rename.rawValue,
            SettingsKey.defaultFormat: ArchiveFormat.sevenZip.rawValue,
            SettingsKey.defaultLevel: CompressionLevel.normal.rawValue,
            SettingsKey.revealAfterExtract: true,
            SettingsKey.revealAfterCreate: true,
            SettingsKey.excludeMacMetadata: true,
            SettingsKey.encryptHeadersByDefault: true
        ])
    }

    static var current: AppSettings {
        let defaults = UserDefaults.standard
        return AppSettings(
            extractionTarget: ExtractionTarget(rawValue: defaults.string(forKey: SettingsKey.extractionTarget) ?? "") ?? .smart,
            overwritePolicy: OverwritePolicy(rawValue: defaults.string(forKey: SettingsKey.overwritePolicy) ?? "") ?? .rename,
            defaultFormat: ArchiveFormat(rawValue: defaults.string(forKey: SettingsKey.defaultFormat) ?? "") ?? .sevenZip,
            defaultLevel: CompressionLevel(rawValue: defaults.integer(forKey: SettingsKey.defaultLevel)) ?? .normal,
            revealAfterExtract: defaults.bool(forKey: SettingsKey.revealAfterExtract),
            revealAfterCreate: defaults.bool(forKey: SettingsKey.revealAfterCreate),
            excludeMacMetadata: defaults.bool(forKey: SettingsKey.excludeMacMetadata),
            encryptHeadersByDefault: defaults.bool(forKey: SettingsKey.encryptHeadersByDefault)
        )
    }
}
