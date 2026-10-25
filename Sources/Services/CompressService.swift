// Sources/Services/CompressService.swift
import Foundation

/// Creates archives with 7zz. Single-process for 7z / zip / tar, two-process pipeline for tar.gz / tar.xz / tar.bz2.
struct CompressService {
    let runner: SevenZipRunner

    @discardableResult
    func create(_ request: CreateRequest, progress: @escaping @Sendable (ProgressUpdate) -> Void) async throws -> String? {
        let fm = FileManager.default
        try fm.createDirectory(at: request.destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        // 7zz "a" updates an existing archive instead of replacing it; a brand-new archive is what the user asked for.
        if fm.fileExists(atPath: request.destination.path) {
            try fm.removeItem(at: request.destination)
        }

        do {
            if request.format.isTarPipeline {
                return try await createThroughTarPipeline(request, progress: progress)
            }
            return try await createDirectly(request, progress: progress)
        } catch {
            // Never leave a half-written archive behind.
            try? fm.removeItem(at: request.destination)
            throw error
        }
    }

    // MARK: - 7z / zip / tar

    private func createDirectly(_ request: CreateRequest, progress: @escaping @Sendable (ProgressUpdate) -> Void) async throws -> String? {
        var arguments = ["a", "-t" + request.format.sevenZipType, "-y", "-bsp1", "-bb1", "-snl"]
        arguments += Self.levelSwitches(for: request)
        arguments += Self.encryptionSwitches(for: request)
        arguments += Self.exclusionSwitches(for: request)
        arguments += ["--", request.destination.path]
        arguments += request.sources.map { $0.path }

        let output = try await runner.run(SevenZipCommand(arguments: arguments), progress: progress)
        if let error = SevenZipRunner.error(from: output) { throw error }
        return output.exitCode == 1 ? warningText(from: output) : nil
    }

    // MARK: - tar.gz / tar.xz / tar.bz2

    /// `7zz a -ttar -so … | 7zz a -si -tgzip out.tar.gz`
    private func createThroughTarPipeline(_ request: CreateRequest, progress: @escaping @Sendable (ProgressUpdate) -> Void) async throws -> String? {
        var producerArguments = ["a", "-ttar", "-so", "-bso0", "-bsp2", "-bb0", "-snl"]
        producerArguments += Self.exclusionSwitches(for: request)
        producerArguments += ["--", "stream.tar"]
        producerArguments += request.sources.map { $0.path }
        let producer = SevenZipCommand(arguments: producerArguments, progressOnStderr: true)

        var consumerArguments = ["a", "-si", "-t" + request.format.sevenZipType, "-y", "-bsp0", "-bb0"]
        consumerArguments += Self.levelSwitches(for: request)
        consumerArguments += ["--", request.destination.path]
        let consumer = SevenZipCommand(arguments: consumerArguments)

        let (producerOutput, consumerOutput) = try await runner.runPipeline(producer: producer, consumer: consumer, progress: progress)
        if let error = SevenZipRunner.error(from: producerOutput) { throw error }
        if let error = SevenZipRunner.error(from: consumerOutput) { throw error }
        if producerOutput.exitCode == 1 || consumerOutput.exitCode == 1 {
            return warningText(from: producerOutput) ?? warningText(from: consumerOutput)
        }
        return nil
    }

    // MARK: - Switch builders

    static func levelSwitches(for request: CreateRequest) -> [String] {
        guard request.format.supportsCompressionLevel else { return [] }
        var switches = ["-mx\(request.level.rawValue)", "-mmt=on"]
        if request.format == .sevenZip, request.level != .store {
            let capMB = dictionaryCapMB()
            if capMB < request.level.defaultDictionaryMB {
                switches.append("-md=\(capMB)m")
            }
        }
        return switches
    }

    static func encryptionSwitches(for request: CreateRequest) -> [String] {
        guard request.format.supportsEncryption, let password = request.password, !password.isEmpty else { return [] }
        var switches = ["-p" + password]
        switch request.format {
        case .sevenZip:
            if request.encryptHeaders { switches.append("-mhe=on") }
        case .zip:
            switches.append("-mem=AES256")
        default:
            break
        }
        return switches
    }

    static func exclusionSwitches(for request: CreateRequest) -> [String] {
        guard request.excludeMacMetadata else { return [] }
        return ["-xr!.DS_Store", "-xr!__MACOSX", "-xr!._*", "-xr!.Spotlight-V100", "-xr!.Trashes", "-xr!.fseventsd"]
    }

    /// Keeps LZMA2 dictionary memory proportional to installed RAM so Ultra never pushes the machine into swap.
    static func dictionaryCapMB() -> Int {
        let ramGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        let cap = Int(ramGB * 8.0)
        return min(max(cap, 16), 64)
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
