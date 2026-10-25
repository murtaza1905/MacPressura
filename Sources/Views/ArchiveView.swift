// Sources/Views/ArchiveView.swift
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ArchiveView: View {
    @EnvironmentObject private var model: MainViewModel

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            if let archive = model.archive {
                header(for: archive)
                Divider()
            }
            table
        }
    }

    // MARK: - Header

    private func header(for archive: ArchiveInfo) -> some View {
        HStack(spacing: 14) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: archive.url.path))
                .resizable()
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(archive.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    statBadge(archive.type.uppercased())
                    statBadge(String(localized: "Archive: \(archive.formattedPhysicalSize)"))
                    statBadge(String(localized: "Content: \(archive.formattedTotalSize)"))
                    statBadge(String(localized: "Ratio: \(archive.compressionRatioText)"))
                    if archive.isSolid && !archive.isNestedTar {
                        statBadge(String(localized: "Solid"))
                    }
                    if archive.hasEncryptedEntries || archive.password != nil {
                        Label(String(localized: "Encrypted"), systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            TextField(String(localized: "Filter"), text: $model.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func statBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    // MARK: - Table

    private var table: some View {
        Table(model.visibleEntries, sortOrder: $model.sortOrder) {
            TableColumn(String(localized: "Name"), value: \.path) { entry in
                HStack(spacing: 6) {
                    Image(nsImage: EntryIconCache.icon(for: entry))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(entry.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if entry.isEncrypted {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .width(min: 260, ideal: 420)

            TableColumn(String(localized: "Size"), value: \.size) { entry in
                Text(entry.formattedSize)
                    .monospacedDigit()
                    .foregroundStyle(entry.isDirectory ? .secondary : .primary)
            }
            .width(min: 80, ideal: 95)

            TableColumn(String(localized: "Packed"), value: \.sortPackedSize) { entry in
                Text(entry.formattedPackedSize)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 95)

            TableColumn(String(localized: "Modified"), value: \.sortModified) { entry in
                Text(entry.modified.map { Self.dateFormatter.string(from: $0) } ?? "—")
                    .monospacedDigit()
            }
            .width(min: 120, ideal: 150)

            TableColumn(String(localized: "Kind"), value: \.kindDescription) { entry in
                Text(entry.kindDescription)
                    .foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 110)
        }
        .overlay {
            if model.visibleEntries.isEmpty {
                if model.searchText.isEmpty {
                    Text("This archive is empty.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No entries match the filter.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension ArchiveEntry {
    var sortPackedSize: Int64 { packedSize ?? 0 }
    var sortModified: Double { modified?.timeIntervalSinceReferenceDate ?? 0 }

    var kindDescription: String {
        if isDirectory { return String(localized: "Folder") }
        let ext = fileExtension
        return ext.isEmpty ? String(localized: "File") : ext.uppercased()
    }
}

/// Finder-style icons per file extension, cached because tables ask for them constantly.
enum EntryIconCache {
    private static var cache: [String: NSImage] = [:]
    private static let lock = NSLock()

    static func icon(for entry: ArchiveEntry) -> NSImage {
        let key = entry.isDirectory ? "/folder" : entry.fileExtension
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[key] { return cached }

        let type: UTType
        if entry.isDirectory {
            type = .folder
        } else if !key.isEmpty, let resolved = UTType(filenameExtension: key) {
            type = resolved
        } else {
            type = .data
        }
        let image = NSWorkspace.shared.icon(for: type)
        image.size = NSSize(width: 16, height: 16)
        cache[key] = image
        return image
    }
}
