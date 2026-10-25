// Sources/Services/ExtractService.swift
import Foundation

/// Extracts archives with 7zz, either directly or through the tar pipeline for .tar.gz / .tar.xz / .tar.bz2 …
struct ExtractService {
    let runner: SevenZipRunner

    /// Runs the extraction and returns a human-readable warning text when 7-Zip reported warnings (exit code 1).
    @discardableResult
    func extract(_ request: ExtractRequest, progress: @escaping @Sendable (ProgressUpdate) -> Void) async throws -> String? {
        try FileManager.default.createDirectory(at: request.destination, withIntermediateDirectories: true)

        if request.isNestedTar {
            return try await extractNestedTar(request, progress: progress)
        }

        let arguments = [
            "x",
            "-y",
            request.overwrite.flag,
            "-bsp1",
            "-bb1",
            "-p" + (request.password ?? ""),
            "-o" + request.destination.path,
            "--",
            request.archiveURL.path
        ]
        let output = try await runner.run(SevenZipCommand(arguments: arguments), progress: progress)
        if let error = SevenZipRunner.error(from: output) { throw error }
        return output.exitCode == 1 ? warningText(from: output) : nil
    }

    /// `7zz x -so archive | 7zz x -si -ttar -o<dest>`
    private func extractNestedTar(_ request: ExtractRequest, progress: @escaping @Sendable (ProgressUpdate) -> Void) async throws -> String? {
        let producer = SevenZipCommand(
            arguments: ["x", "-so", "-bso0", "-bsp2", "-y", "-p" + (request.password ?? ""), "--", request.archiveURL.path],
            progressOnStderr: true
        )
        let consumer = SevenZipCommand(
            arguments: ["x", "-si", "-ttar", "-y", request.overwrite.flag, "-bsp0", "-bb1", "-o" + request.destination.path]
        )
        let (producerOutput, consumerOutput) = try await runner.runPipeline(producer: producer, consumer: consumer, progress: progress)
        if let error = SevenZipRunner.error(from: producerOutput) { throw error }
        if let error = SevenZipRunner.error(from: consumerOutput) { throw error }
        if producerOutput.exitCode == 1 || consumerOutput.exitCode == 1 {
            return warningText(from: consumerOutput) ?? warningText(from: producerOutput)
        }
        return nil
    }

    private func warningText(from output: SevenZipOutput) -> String? {
        let summary = output.errorSummary
        if !summary.isEmpty { return summary }
        for line in output.stdoutLines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().contains("warning") { return trimmed }
        }
        return String(localized: "Completed with warnings.")
    }
}
