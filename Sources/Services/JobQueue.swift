// Sources/Services/JobQueue.swift
import Foundation
import AppKit

/// Runs extraction and compression jobs one at a time (parallel jobs only compete for the same cores)
/// and publishes their progress to the UI at a bounded rate.
@MainActor
final class JobQueue: ObservableObject {
    @Published private(set) var jobs: [Job] = []
    @Published private(set) var isBusy: Bool = false

    private let engine: ArchiveEngine
    private var runningTask: Task<Void, Never>?
    private var runningJobID: UUID?
    private let relay = ProgressRelay()
    private var relayTimer: Timer?

    var onJobFinished: ((Job) -> Void)?

    init(engine: ArchiveEngine) {
        self.engine = engine
    }

    // MARK: - Public API

    @discardableResult
    func enqueue(_ operation: JobOperation, title: String, detail: String) -> Job {
        let job = Job(operation: operation, title: title, detail: detail)
        jobs.append(job)
        pump()
        return job
    }

    func cancel(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        if jobs[index].state == .queued {
            jobs[index].state = .cancelled
            jobs[index].finishedAt = Date()
        } else if jobs[index].state == .running, runningJobID == id {
            runningTask?.cancel()
        }
    }

    func remove(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }), jobs[index].state.isDone else { return }
        jobs.remove(at: index)
    }

    func clearFinished() {
        jobs.removeAll { $0.state.isDone }
    }

    var activeCount: Int {
        jobs.filter { $0.state.isActive }.count
    }

    // MARK: - Scheduling

    private func pump() {
        guard runningTask == nil else { return }
        guard let index = jobs.firstIndex(where: { $0.state == .queued }) else {
            isBusy = false
            return
        }
        let job = jobs[index]
        isBusy = true
        runningJobID = job.id
        jobs[index].state = .running
        jobs[index].startedAt = Date()
        startRelayTimer()

        runningTask = Task { [weak self] in
            guard let self else { return }
            await self.execute(job)
            await MainActor.run {
                self.stopRelayTimer()
                self.runningTask = nil
                self.runningJobID = nil
                self.pump()
            }
        }
    }

    private func execute(_ job: Job) async {
        let relay = self.relay
        relay.reset()
        let progress: @Sendable (ProgressUpdate) -> Void = { update in
            relay.push(update)
        }

        var finalState: JobState
        var resultURL: URL?

        do {
            switch job.operation {
            case .extract(let request):
                let warning = try await engine.extractor.extract(request, progress: progress)
                resultURL = request.destination
                finalState = warning.map { .finishedWithWarnings($0) } ?? .finished
            case .create(let request):
                let warning = try await engine.compressor.create(request, progress: progress)
                resultURL = request.destination
                finalState = warning.map { .finishedWithWarnings($0) } ?? .finished
            }
        } catch let error as SevenZipError {
            if case .cancelled = error {
                finalState = .cancelled
            } else {
                finalState = .failed(error.localizedDescription)
            }
        } catch {
            finalState = Task.isCancelled ? .cancelled : .failed(error.localizedDescription)
        }

        let state = finalState
        let url = resultURL
        await MainActor.run {
            self.applyLatestProgress()
            guard let index = self.jobs.firstIndex(where: { $0.id == job.id }) else { return }
            self.jobs[index].state = state
            self.jobs[index].finishedAt = Date()
            self.jobs[index].resultURL = url
            if case .finished = state { self.jobs[index].progress = 1 }
            if case .finishedWithWarnings = state { self.jobs[index].progress = 1 }
            self.onJobFinished?(self.jobs[index])
        }
    }

    // MARK: - Progress relay (background → main, max ~10 updates/s)

    private func startRelayTimer() {
        relayTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyLatestProgress()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        relayTimer = timer
    }

    private func stopRelayTimer() {
        relayTimer?.invalidate()
        relayTimer = nil
    }

    private func applyLatestProgress() {
        guard let runningJobID, let snapshot = relay.takeSnapshot(),
              let index = jobs.firstIndex(where: { $0.id == runningJobID }) else { return }
        if let percent = snapshot.percent {
            jobs[index].progress = Double(percent) / 100.0
        }
        if let count = snapshot.processedCount {
            jobs[index].processedCount = count
        }
        if let item = snapshot.currentItem {
            jobs[index].currentItem = item
        }
    }
}

/// Thread-safe mailbox holding the most recent progress values reported by the engine threads.
final class ProgressRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var percent: Int?
    private var processedCount: Int?
    private var currentItem: String?
    private var dirty = false

    func reset() {
        lock.lock(); defer { lock.unlock() }
        percent = nil
        processedCount = nil
        currentItem = nil
        dirty = false
    }

    func push(_ update: ProgressUpdate) {
        lock.lock(); defer { lock.unlock() }
        if let value = update.percent { percent = value }
        if let value = update.processedCount { processedCount = value }
        if let value = update.currentItem { currentItem = value }
        dirty = true
    }

    func takeSnapshot() -> ProgressUpdate? {
        lock.lock(); defer { lock.unlock() }
        guard dirty else { return nil }
        dirty = false
        return ProgressUpdate(percent: percent, processedCount: processedCount, currentItem: currentItem)
    }
}
