// Sources/Engine/ArchiveLister.swift
import Foundation

/// Reads an archive's table of contents through `7zz l -slt` and turns it into `ArchiveInfo`.
struct ArchiveLister {
    let runner: SevenZipRunner

    func list(url: URL, password: String?) async throws -> ArchiveInfo {
        let arguments = ["l", "-slt", passwordSwitch(password), "--", url.path].filter { !$0.isEmpty }
        let output = try await runner.run(SevenZipCommand(arguments: arguments, keepAllStdout: true))
        if let error = SevenZipRunner.error(from: output) { throw error }

        let parsed = TechnicalListingParser.parse(output.stdoutLines)
        let type = parsed.archiveProperties["Type"] ?? ""

        if Self.looksLikeNestedTar(url: url, type: type, entries: parsed.entries) {
            return try await listNestedTar(url: url, password: password, outerType: type, outerProperties: parsed.archiveProperties)
        }

        return ArchiveInfo(
            url: url,
            type: type,
            physicalSize: Int64(parsed.archiveProperties["Physical Size"] ?? "") ?? Self.fileSize(of: url),
            isSolid: parsed.archiveProperties["Solid"] == "+",
            method: parsed.archiveProperties["Method"],
            entries: parsed.entries,
            isNestedTar: false,
            password: password
        )
    }

    /// `7zz x -so archive | 7zz l -si -ttar -slt`
    private func listNestedTar(url: URL, password: String?, outerType: String, outerProperties: [String: String]) async throws -> ArchiveInfo {
        let producer = SevenZipCommand(
            arguments: ["x", "-so", "-bso0", "-bsp0", "-y", passwordSwitch(password), "--", url.path].filter { !$0.isEmpty },
            progressOnStderr: true
        )
        let consumer = SevenZipCommand(
            arguments: ["l", "-si", "-ttar", "-slt"],
            keepAllStdout: true
        )
        let (producerOutput, consumerOutput) = try await runner.runPipeline(producer: producer, consumer: consumer)
        if let error = SevenZipRunner.error(from: producerOutput) { throw error }
        if let error = SevenZipRunner.error(from: consumerOutput) { throw error }

        let parsed = TechnicalListingParser.parse(consumerOutput.stdoutLines)
        return ArchiveInfo(
            url: url,
            type: "tar." + outerType.lowercased(),
            physicalSize: Self.fileSize(of: url),
            isSolid: true,
            method: outerProperties["Method"],
            entries: parsed.entries,
            isNestedTar: true,
            password: password
        )
    }

    private func passwordSwitch(_ password: String?) -> String {
        // Always pass -p: without it 7zz would wait for an interactive password prompt.
        "-p" + (password ?? "")
    }

    static func looksLikeNestedTar(url: URL, type: String, entries: [ArchiveEntry]) -> Bool {
        let singleFileTypes: Set<String> = ["gzip", "bzip2", "xz", "zstd", "lzma", "lz4", "z", "lzip"]
        guard singleFileTypes.contains(type.lowercased()) else { return false }
        guard entries.count == 1, let only = entries.first, !only.isDirectory else { return false }
        if only.name.lowercased().hasSuffix(".tar") { return true }
        let archiveName = url.lastPathComponent.lowercased()
        let tarballSuffixes = [".tar.gz", ".tgz", ".tar.bz2", ".tbz", ".tbz2", ".tar.xz", ".txz", ".tar.zst", ".tzst", ".tar.lz", ".tar.lzma", ".tar.lz4", ".tar.z", ".taz"]
        return tarballSuffixes.contains { archiveName.hasSuffix($0) }
    }

    static func fileSize(of url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize.map(Int64.init)
    }
}

/// Parses the `Key = Value` blocks produced by `7zz l -slt`.
enum TechnicalListingParser {
    struct Result {
        var archiveProperties: [String: String] = [:]
        var entries: [ArchiveEntry] = []
    }

    private static let dateFormatterWithFraction: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func parse(_ lines: [String]) -> Result {
        var result = Result()

        guard let separatorIndex = lines.firstIndex(of: "----------") else {
            return result
        }

        // Archive properties: between the "--" marker and the "----------" separator.
        var headerStart = 0
        if let dashIndex = lines[..<separatorIndex].lastIndex(of: "--") {
            headerStart = dashIndex + 1
        }
        for line in lines[headerStart..<separatorIndex] {
            if let (key, value) = splitKeyValue(line) {
                result.archiveProperties[key] = value
            }
        }

        // Entries: blank-line separated blocks after the separator.
        var block: [String: String] = [:]
        var index = 0
        var entries: [ArchiveEntry] = []
        entries.reserveCapacity(max(lines.count / 10, 16))

        func flush() {
            if let entry = makeEntry(from: block, id: index) {
                entries.append(entry)
                index += 1
            }
            block.removeAll(keepingCapacity: true)
        }

        for line in lines[(separatorIndex + 1)...] {
            if line.isEmpty {
                if !block.isEmpty { flush() }
                continue
            }
            if let (key, value) = splitKeyValue(line) {
                if key == "Path", !block.isEmpty {
                    flush()
                }
                block[key] = value
            }
        }
        if !block.isEmpty { flush() }

        result.entries = entries
        return result
    }

    static func splitKeyValue(_ line: String) -> (String, String)? {
        guard let range = line.range(of: " = ") else {
            if line.hasSuffix(" =") {
                return (String(line.dropLast(2)), "")
            }
            return nil
        }
        let key = String(line[line.startIndex..<range.lowerBound])
        let value = String(line[range.upperBound...])
        return (key, value)
    }

    static func makeEntry(from block: [String: String], id: Int) -> ArchiveEntry? {
        guard var path = block["Path"], !path.isEmpty else { return nil }

        // Normalise separators and strip trailing slashes.
        path = path.replacingOccurrences(of: "\\", with: "/")
        while path.hasSuffix("/") { path.removeLast() }
        guard !path.isEmpty else { return nil }

        let attributes = block["Attributes"] ?? ""
        let mode = block["Mode"] ?? ""
        let folderFlag = block["Folder"]
        let isDirectory: Bool
        if let folderFlag {
            isDirectory = folderFlag == "+"
        } else if attributes.hasPrefix("D") {
            isDirectory = true
        } else if mode.hasPrefix("d") {
            isDirectory = true
        } else {
            isDirectory = false
        }

        let name = path.split(separator: "/").last.map(String.init) ?? path
        let size = Int64(block["Size"] ?? "") ?? 0
        let packed = Int64(block["Packed Size"] ?? "")
        let encrypted = (block["Encrypted"] ?? "-") == "+"
        let crc = block["CRC"].flatMap { $0.isEmpty ? nil : $0 }
        let method = block["Method"].flatMap { $0.isEmpty ? nil : $0 }
        let modified = parseDate(block["Modified"])

        return ArchiveEntry(
            id: id,
            path: path,
            name: name,
            size: size,
            packedSize: packed,
            modified: modified,
            isDirectory: isDirectory,
            isEncrypted: encrypted,
            crc: crc,
            method: method
        )
    }

    static func parseDate(_ text: String?) -> Date? {
        guard let text, text.count >= 19 else { return nil }
        let base = String(text.prefix(19))
        return dateFormatterWithFraction.date(from: base)
    }
}
