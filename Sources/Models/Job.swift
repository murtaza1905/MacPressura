// Sources/Models/Job.swift
import Foundation

struct ExtractRequest: Equatable {
    let archiveURL: URL
    let destination: URL
    let overwrite: OverwritePolicy
    let password: String?
    /// gzip/xz/bzip2… wrapping a tar stream: extracted through a two-process pipeline.
    let isNestedTar: Bool
}

struct CreateRequest: Equatable {
    let sources: [URL]
    let destination: URL
    let format: ArchiveFormat
    let level: CompressionLevel
    let password: String?
    let encryptHeaders: Bool
    let excludeMacMetadata: Bool
}

enum JobOperation: Equatable {
    case extract(ExtractRequest)
    case create(CreateRequest)
}

enum JobState: Equatable {
    case queued
    case running
    case finished
    case finishedWithWarnings(String)
    case failed(String)
    case cancelled

    var isActive: Bool {
        switch self {
        case .queued, .running: return true
        default: return false
        }
    }

    var isDone: Bool { !isActive }
}

struct Job: Identifiable, Equatable {
    let id: UUID
    let operation: JobOperation
    let title: String
    let detail: String
    var state: JobState = .queued
    var progress: Double = 0
    var currentItem: String = ""
    var processedCount: Int = 0
    var startedAt: Date?
    var finishedAt: Date?
    var resultURL: URL?

    init(operation: JobOperation, title: String, detail: String) {
        self.id = UUID()
        self.operation = operation
        self.title = title
        self.detail = detail
    }

    var isExtract: Bool {
        if case .extract = operation { return true }
        return false
    }

    var elapsedText: String {
        guard let startedAt else { return "" }
        let end = finishedAt ?? Date()
        let seconds = Int(end.timeIntervalSince(startedAt))
        if seconds < 60 { return "\(seconds) s" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Progress data emitted by the engine while a job runs.
struct ProgressUpdate: Equatable {
    var percent: Int?
    var processedCount: Int?
    var currentItem: String?
}
