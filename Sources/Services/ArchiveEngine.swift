// Sources/Services/ArchiveEngine.swift
import Foundation

/// Single entry point to the 7-Zip engine for the rest of the app.
final class ArchiveEngine {
    let runner: SevenZipRunner
    let lister: ArchiveLister
    let extractor: ExtractService
    let compressor: CompressService

    init(runner: SevenZipRunner) {
        self.runner = runner
        self.lister = ArchiveLister(runner: runner)
        self.extractor = ExtractService(runner: runner)
        self.compressor = CompressService(runner: runner)
    }

    static func makeDefault() throws -> ArchiveEngine {
        ArchiveEngine(runner: try SevenZipRunner.makeDefault())
    }

    /// Reads the engine banner, e.g. "7-Zip (z) 26.05 (arm64)". Informational only.
    func fetchVersionBanner() async -> String {
        guard let output = try? await runner.run(SevenZipCommand(arguments: ["i"], keepAllStdout: false)) else {
            return "7-Zip"
        }
        for line in output.stdoutLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("7-Zip") {
                if let range = trimmed.range(of: " : ") {
                    return String(trimmed[trimmed.startIndex..<range.lowerBound])
                }
                return trimmed
            }
        }
        return "7-Zip"
    }
}
