// Sources/Engine/SevenZipRunner.swift
import Foundation

enum SevenZipError: LocalizedError, Equatable {
    case engineNotFound
    case wrongPassword
    case notAnArchive
    case cancelled
    case failed(exitCode: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .engineNotFound:
            return String(localized: "The 7-Zip engine (7zz) could not be found inside the app bundle. Rebuild the app with ./build.sh.")
        case .wrongPassword:
            return String(localized: "Wrong password.")
        case .notAnArchive:
            return String(localized: "This file is not a supported archive, or it is damaged.")
        case .cancelled:
            return String(localized: "Cancelled.")
        case .failed(let exitCode, let message):
            if message.isEmpty {
                return String(localized: "7-Zip failed with exit code \(Int(exitCode)).")
            }
            return message
        }
    }
}

/// Locates the bundled 7-Zip engine.
enum SevenZipLocator {
    static func locate() -> URL? {
        let fm = FileManager.default
        if let url = Bundle.main.url(forAuxiliaryExecutable: "7zz"), fm.isExecutableFile(atPath: url.path) {
            return url
        }
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/7zz").path,
            "/opt/homebrew/bin/7zz",
            "/usr/local/bin/7zz"
        ]
        for path in candidates where fm.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}

/// Output of one 7-Zip invocation.
struct SevenZipOutput {
    let exitCode: Int32
    let stdoutLines: [String]
    let stderrLines: [String]
    let wasCancelled: Bool

    var combinedText: String {
        (stdoutLines + stderrLines).joined(separator: "\n")
    }

    /// Picks the most useful human-readable error line.
    var errorSummary: String {
        let candidates = stderrLines + stdoutLines.reversed()
        for line in candidates {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("ERROR:") || trimmed.hasPrefix("ERROR ") {
                return trimmed.replacingOccurrences(of: "ERROR:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        for line in stderrLines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }
}

/// One command invocation: `7zz <arguments>`.
struct SevenZipCommand {
    var arguments: [String]
    var currentDirectory: URL? = nil
    /// Which stream carries the in-place progress indicator (`-bsp1` → stdout, `-bsp2` → stderr).
    var progressOnStderr: Bool = false
    /// Keep every stdout line (needed for listings). Otherwise only a tail is retained.
    var keepAllStdout: Bool = false
}

/// Runs the bundled 7zz binary asynchronously, reporting progress, supporting cancellation.
final class SevenZipRunner {
    let executable: URL

    init(executable: URL) {
        self.executable = executable
    }

    static func makeDefault() throws -> SevenZipRunner {
        guard let url = SevenZipLocator.locate() else { throw SevenZipError.engineNotFound }
        return SevenZipRunner(executable: url)
    }

    // MARK: - Single process

    func run(_ command: SevenZipCommand,
             progress: (@Sendable (ProgressUpdate) -> Void)? = nil) async throws -> SevenZipOutput {
        let process = makeProcess(command)
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        let stdoutReader = StreamReader(
            handle: stdoutPipe.fileHandleForReading,
            keepAll: command.keepAllStdout,
            parsesProgress: !command.progressOnStderr,
            progress: progress
        )
        let stderrReader = StreamReader(
            handle: stderrPipe.fileHandleForReading,
            keepAll: true,
            parsesProgress: command.progressOnStderr,
            progress: progress
        )

        let session = ProcessSession(process: process, readers: [stdoutReader, stderrReader])
        let exitCode = try await session.runAndWait()
        let cancelled = Task.isCancelled

        return SevenZipOutput(
            exitCode: exitCode,
            stdoutLines: stdoutReader.lines,
            stderrLines: stderrReader.lines,
            wasCancelled: cancelled
        )
    }

    // MARK: - Two-process pipeline (`7zz … -so | 7zz … -si`)

    func runPipeline(producer: SevenZipCommand,
                     consumer: SevenZipCommand,
                     progress: (@Sendable (ProgressUpdate) -> Void)? = nil) async throws -> (producer: SevenZipOutput, consumer: SevenZipOutput) {
        let first = makeProcess(producer)
        let second = makeProcess(consumer)

        let link = Pipe()
        let firstErr = Pipe()
        let secondOut = Pipe()
        let secondErr = Pipe()

        first.standardOutput = link
        first.standardError = firstErr
        first.standardInput = FileHandle.nullDevice

        second.standardInput = link
        second.standardOutput = secondOut
        second.standardError = secondErr

        // The producer's stderr carries the progress indicator (-bsp2); the consumer's stdout carries item names (-bb1).
        let firstErrReader = StreamReader(handle: firstErr.fileHandleForReading, keepAll: true, parsesProgress: true, progress: progress)
        let secondOutReader = StreamReader(handle: secondOut.fileHandleForReading, keepAll: consumer.keepAllStdout, parsesProgress: false, progress: progress)
        let secondErrReader = StreamReader(handle: secondErr.fileHandleForReading, keepAll: true, parsesProgress: false, progress: nil)

        let firstSession = ProcessSession(process: first, readers: [firstErrReader])
        let secondSession = ProcessSession(process: second, readers: [secondOutReader, secondErrReader])

        let exitCodes: (Int32, Int32) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int32, Int32), Error>) in
                let group = DispatchGroup()
                let firstCode = LockedBox<Int32>(-1)
                let secondCode = LockedBox<Int32>(-1)
                let launchError = LockedBox<Error?>(nil)

                group.enter()
                firstSession.start { code in
                    firstCode.value = code
                    group.leave()
                } failure: { error in
                    launchError.value = error
                    group.leave()
                }

                // The parent no longer needs the link's write end once the producer owns it. Closing it here
                // guarantees the consumer cannot inherit it and will see EOF as soon as the producer exits.
                try? link.fileHandleForWriting.close()

                group.enter()
                secondSession.start { code in
                    secondCode.value = code
                    group.leave()
                } failure: { error in
                    launchError.value = error
                    group.leave()
                }

                group.notify(queue: .global()) {
                    if let error = launchError.value {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: (firstCode.value, secondCode.value))
                    }
                }
            }
        } onCancel: {
            firstSession.terminate()
            secondSession.terminate()
        }

        let cancelled = Task.isCancelled
        let producerOutput = SevenZipOutput(exitCode: exitCodes.0, stdoutLines: [], stderrLines: firstErrReader.lines, wasCancelled: cancelled)
        let consumerOutput = SevenZipOutput(exitCode: exitCodes.1, stdoutLines: secondOutReader.lines, stderrLines: secondErrReader.lines, wasCancelled: cancelled)
        return (producerOutput, consumerOutput)
    }

    // MARK: - Helpers

    private func makeProcess(_ command: SevenZipCommand) -> Process {
        let process = Process()
        process.executableURL = executable
        process.arguments = command.arguments
        process.currentDirectoryURL = command.currentDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        process.environment = environment
        return process
    }

    /// Interprets exit codes and messages into a typed error. Returns nil when the run is acceptable (0 = ok, 1 = warnings).
    static func error(from output: SevenZipOutput) -> SevenZipError? {
        if output.wasCancelled { return .cancelled }
        switch output.exitCode {
        case 0, 1:
            return nil
        default:
            let text = output.combinedText
            if text.contains("Wrong password") || text.contains("Enter password") {
                return .wrongPassword
            }
            if text.contains("Cannot open the file as archive") || text.contains("Can not open the file as archive") || text.contains("Can't open as archive") {
                return .notAnArchive
            }
            return .failed(exitCode: output.exitCode, message: output.errorSummary)
        }
    }
}

// MARK: - Process plumbing

/// Reads one file handle on a background thread, assembling console lines and reporting progress.
final class StreamReader: @unchecked Sendable {
    private let handle: FileHandle
    private let keepAll: Bool
    private let parsesProgress: Bool
    private let progress: (@Sendable (ProgressUpdate) -> Void)?
    private let lock = NSLock()
    private var storedLines: [String] = []
    private var assembler = ConsoleLineAssembler()
    private var lastReportedPercent: Int = -1
    private static let tailLimit = 400

    init(handle: FileHandle, keepAll: Bool, parsesProgress: Bool, progress: (@Sendable (ProgressUpdate) -> Void)?) {
        self.handle = handle
        self.keepAll = keepAll
        self.parsesProgress = parsesProgress
        self.progress = progress
    }

    var lines: [String] {
        lock.lock(); defer { lock.unlock() }
        return storedLines
    }

    /// Blocks the calling thread until EOF.
    func readToEnd() {
        while true {
            let data = handle.availableData
            if data.isEmpty { break }
            ingest(data)
        }
        if let rest = assembler.flush() {
            store(rest)
            report(completed: rest)
        }
        try? handle.close()
    }

    private func ingest(_ data: Data) {
        let (completed, current) = assembler.feed(data)
        for line in completed {
            store(line)
            report(completed: line)
        }
        if parsesProgress, let update = ProgressLineParser.parse(current) {
            if let percent = update.percent, percent != lastReportedPercent {
                lastReportedPercent = percent
                progress?(update)
            } else if update.currentItem != nil {
                progress?(update)
            }
        }
    }

    private func report(completed line: String) {
        guard let progress else { return }
        if let item = ProgressLineParser.itemName(fromCompletedLine: line) {
            progress(ProgressUpdate(percent: nil, processedCount: nil, currentItem: item))
        } else if parsesProgress, let update = ProgressLineParser.parse(line), let percent = update.percent {
            lastReportedPercent = percent
            progress(update)
        }
    }

    private func store(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        storedLines.append(line)
        if !keepAll, storedLines.count > Self.tailLimit {
            storedLines.removeFirst(storedLines.count - Self.tailLimit)
        }
    }
}

/// Minimal lock-protected mutable cell, so closures handed to GCD never capture mutable locals.
final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); defer { lock.unlock() }; storage = newValue }
    }
}

/// Launches a Process, drains its pipes on background threads, and reports the exit code once everything is done.
final class ProcessSession: @unchecked Sendable {
    private let process: Process
    private let readers: [StreamReader]
    private let queue = DispatchQueue(label: "com.muratonurcu.MacPressura.process", attributes: .concurrent)
    private let stateLock = NSLock()
    private var started = false
    private var terminated = false

    init(process: Process, readers: [StreamReader]) {
        self.process = process
        self.readers = readers
    }

    func start(completion: @escaping @Sendable (Int32) -> Void, failure: @escaping @Sendable (Error) -> Void) {
        let group = DispatchGroup()
        for reader in readers {
            group.enter()
            queue.async {
                reader.readToEnd()
                group.leave()
            }
        }

        let exitCode = LockedBox<Int32>(-1)
        group.enter()
        process.terminationHandler = { proc in
            exitCode.value = proc.terminationStatus
            group.leave()
        }

        stateLock.lock()
        let shouldLaunch = !terminated
        started = true
        stateLock.unlock()

        do {
            if shouldLaunch {
                try process.run()
                // A cancellation that raced the launch is honoured here instead of being lost.
                stateLock.lock()
                let cancelledMeanwhile = terminated
                stateLock.unlock()
                if cancelledMeanwhile { terminateProcess() }
            } else {
                // Cancelled before launch: unblock the readers by closing the write ends we still own.
                process.terminationHandler = nil
                group.leave()
                closeOutputs()
            }
        } catch {
            process.terminationHandler = nil
            group.leave()
            closeOutputs()
            group.notify(queue: .global()) {
                failure(error)
            }
            return
        }

        group.notify(queue: .global()) {
            completion(exitCode.value)
        }
    }

    func runAndWait() async throws -> Int32 {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
                start { code in
                    continuation.resume(returning: code)
                } failure: { error in
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            terminate()
        }
    }

    func terminate() {
        stateLock.lock()
        terminated = true
        let isRunning = started && process.isRunning
        stateLock.unlock()
        if isRunning {
            terminateProcess()
        }
    }

    private func terminateProcess() {
        guard process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        let proc = process
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if proc.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }

    /// Closes the write ends of the process's output pipes so blocked readers hit EOF.
    private func closeOutputs() {
        if let pipe = process.standardOutput as? Pipe { try? pipe.fileHandleForWriting.close() }
        if let pipe = process.standardError as? Pipe { try? pipe.fileHandleForWriting.close() }
    }
}
