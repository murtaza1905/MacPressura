// Sources/Models/ArchiveModels.swift
import Foundation

/// Archive formats MacPressura can create.
/// RAR creation is not possible: the RAR compressor is proprietary. RAR archives can still be opened and extracted.
enum ArchiveFormat: String, CaseIterable, Identifiable, Codable {
    case sevenZip
    case zip
    case tarGz
    case tarXz
    case tarBz2
    case tar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sevenZip: return "7z"
        case .zip:      return "ZIP"
        case .tarGz:    return "TAR.GZ"
        case .tarXz:    return "TAR.XZ"
        case .tarBz2:   return "TAR.BZ2"
        case .tar:      return "TAR"
        }
    }

    var fileExtension: String {
        switch self {
        case .sevenZip: return "7z"
        case .zip:      return "zip"
        case .tarGz:    return "tar.gz"
        case .tarXz:    return "tar.xz"
        case .tarBz2:   return "tar.bz2"
        case .tar:      return "tar"
        }
    }

    /// 7-Zip `-t` type used by the (final) compressor.
    var sevenZipType: String {
        switch self {
        case .sevenZip: return "7z"
        case .zip:      return "zip"
        case .tarGz:    return "gzip"
        case .tarXz:    return "xz"
        case .tarBz2:   return "bzip2"
        case .tar:      return "tar"
        }
    }

    /// Formats produced by piping a tar stream into a single-file compressor.
    var isTarPipeline: Bool {
        switch self {
        case .tarGz, .tarXz, .tarBz2: return true
        default: return false
        }
    }

    var supportsEncryption: Bool {
        self == .sevenZip || self == .zip
    }

    var supportsHeaderEncryption: Bool {
        self == .sevenZip
    }

    var supportsCompressionLevel: Bool {
        self != .tar
    }
}

/// Maps to 7-Zip `-mx` levels.
enum CompressionLevel: Int, CaseIterable, Identifiable, Codable {
    case store = 0
    case fastest = 1
    case fast = 3
    case normal = 5
    case maximum = 7
    case ultra = 9

    var id: Int { rawValue }

    var localizedName: String {
        switch self {
        case .store:   return String(localized: "Store (no compression)")
        case .fastest: return String(localized: "Fastest")
        case .fast:    return String(localized: "Fast")
        case .normal:  return String(localized: "Normal")
        case .maximum: return String(localized: "Maximum")
        case .ultra:   return String(localized: "Ultra")
        }
    }

    /// Default LZMA2 dictionary size (MB) 7-Zip picks for this level.
    var defaultDictionaryMB: Int {
        switch self {
        case .store:   return 0
        case .fastest: return 1
        case .fast:    return 4
        case .normal:  return 16
        case .maximum: return 32
        case .ultra:   return 64
        }
    }
}

/// Maps to 7-Zip `-ao` overwrite switches.
enum OverwritePolicy: String, CaseIterable, Identifiable, Codable {
    case rename
    case skip
    case overwrite

    var id: String { rawValue }

    var flag: String {
        switch self {
        case .overwrite: return "-aoa"
        case .skip:      return "-aos"
        case .rename:    return "-aou"
        }
    }

    var localizedName: String {
        switch self {
        case .rename:    return String(localized: "Keep both (rename new file)")
        case .skip:      return String(localized: "Skip existing files")
        case .overwrite: return String(localized: "Overwrite existing files")
        }
    }
}

/// Where extracted content goes.
enum ExtractionTarget: String, CaseIterable, Identifiable, Codable {
    case smart
    case here
    case subfolder
    case ask

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .smart:     return String(localized: "Smart (subfolder unless the archive has a single root item)")
        case .here:      return String(localized: "Next to the archive")
        case .subfolder: return String(localized: "Into a folder named after the archive")
        case .ask:       return String(localized: "Ask for a folder")
        }
    }
}

struct ArchiveEntry: Identifiable, Hashable {
    let id: Int
    let path: String
    let name: String
    let size: Int64
    let packedSize: Int64?
    let modified: Date?
    let isDirectory: Bool
    let isEncrypted: Bool
    let crc: String?
    let method: String?

    var formattedSize: String {
        isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedPackedSize: String {
        guard let packedSize, !isDirectory else { return "—" }
        return ByteCountFormatter.string(fromByteCount: packedSize, countStyle: .file)
    }

    var parentPath: String {
        guard let range = path.range(of: "/", options: .backwards) else { return "" }
        return String(path[path.startIndex..<range.lowerBound])
    }

    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }
}

struct ArchiveInfo {
    let url: URL
    let type: String
    let physicalSize: Int64?
    let isSolid: Bool
    let method: String?
    let entries: [ArchiveEntry]
    /// True when the archive is a single-file compressor (gzip, xz, bzip2, zstd…) wrapping a tar stream.
    let isNestedTar: Bool
    let password: String?

    var name: String { url.lastPathComponent }

    var fileCount: Int { entries.lazy.filter { !$0.isDirectory }.count }
    var folderCount: Int { entries.lazy.filter { $0.isDirectory }.count }
    var totalSize: Int64 { entries.reduce(0) { $0 + ($1.isDirectory ? 0 : $1.size) } }

    var hasEncryptedEntries: Bool {
        entries.contains { $0.isEncrypted }
    }

    /// Distinct top-level names (first path component) inside the archive.
    var topLevelNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in entries {
            let first = entry.path.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? entry.path
            if !first.isEmpty, seen.insert(first).inserted {
                result.append(first)
            }
        }
        return result
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var formattedPhysicalSize: String {
        guard let physicalSize else { return "—" }
        return ByteCountFormatter.string(fromByteCount: physicalSize, countStyle: .file)
    }

    var compressionRatioText: String {
        guard let physicalSize, totalSize > 0 else { return "—" }
        let ratio = Double(physicalSize) / Double(totalSize) * 100
        return String(format: "%.0f%%", ratio)
    }
}

/// Knows which file extensions MacPressura treats as archives (for drag & drop routing).
enum ArchiveFileTypes {
    static let extensions: Set<String> = [
        "7z", "zip", "rar", "tar", "gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz",
        "zst", "tzst", "lz", "lzma", "lz4", "z", "taz", "iso", "dmg", "cab", "arj",
        "lzh", "lha", "wim", "swm", "esd", "cpio", "rpm", "deb", "xar", "pkg",
        "001", "msi", "chm", "vhd", "vhdx", "vmdk", "udf", "jar", "war", "ear",
        "apk", "ipa", "img", "squashfs", "cramfs", "hfs", "nsis", "exe"
    ]

    /// Extensions where a plain `l -slt` returns a single inner `.tar` entry.
    static let singleFileCompressors: Set<String> = ["gz", "bz2", "xz", "zst", "lz", "lzma", "lz4", "z", "tgz", "tbz", "tbz2", "txz", "tzst", "taz"]

    static func isArchive(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        if ext == "exe" { return false }   // only listed for completeness; never auto-open executables
        return extensions.contains(ext)
    }

    /// "report.tar.gz" -> "report", "photos.7z.001" -> "photos", "notes.zip" -> "notes"
    static func stem(for url: URL) -> String {
        var name = url.lastPathComponent
        let lower = name.lowercased()
        let doubleSuffixes = [".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tar.lz", ".tar.lzma", ".tar.lz4", ".tar.z", ".7z.001", ".zip.001", ".rar.001", ".part1.rar", ".part01.rar"]
        for suffix in doubleSuffixes where lower.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            return name.isEmpty ? url.lastPathComponent : name
        }
        let withoutExt = (name as NSString).deletingPathExtension
        return withoutExt.isEmpty ? name : withoutExt
    }
}
