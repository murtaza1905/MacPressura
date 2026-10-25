// Sources/ViewModels/MainViewModel.swift
import Foundation
import AppKit
import SwiftUI
import Combine

struct PasswordPrompt: Identifiable {
    let id = UUID()
    let fileName: String
    let isRetry: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
}

struct NewArchiveDraft: Identifiable {
    let id = UUID()
    var sources: [URL]
    var directory: URL
    var baseName: String
    var format: ArchiveFormat
    var level: CompressionLevel
    var encryptHeaders: Bool
    var excludeMacMetadata: Bool
}

struct UserFacingError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Drives the main window: opening/listing archives, routing drops, building jobs.
@MainActor
final class MainViewModel: ObservableObject {
    @Published private(set) var archive: ArchiveInfo?
    @Published private(set) var isLoading = false
    @Published private(set) var loadingName = ""
    @Published var isDropTargeted = false
    @Published var error: UserFacingError?
    @Published var passwordPrompt: PasswordPrompt?
    @Published var newArchiveDraft: NewArchiveDraft?
    @Published var searchText = "" { didSet { refreshVisibleEntries() } }
    @Published var sortOrder: [KeyPathComparator<ArchiveEntry>] = [KeyPathComparator(\.path)] { didSet { refreshVisibleEntries() } }
    @Published private(set) var visibleEntries: [ArchiveEntry] = []
    @Published private(set) var engineBanner: String = ""
    @Published var showJobs = true

    let engineAvailable: Bool
    let jobQueue: JobQueue
    private let engine: ArchiveEngine
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?

    init() {
        AppSettings.registerDefaults()

        let locatedEngine: ArchiveEngine
        let available: Bool
        if let located = SevenZipLocator.locate() {
            locatedEngine = ArchiveEngine(runner: SevenZipRunner(executable: located))
            available = true
        } else {
            locatedEngine = ArchiveEngine(runner: SevenZipRunner(executable: URL(fileURLWithPath: "/nonexistent/7zz")))
            available = false
        }
        let queue = JobQueue(engine: locatedEngine)
        engine = locatedEngine
        engineAvailable = available
        jobQueue = queue

        queue.onJobFinished = { [weak self] job in
            self?.handleFinished(job)
        }

        OpenURLRelay.shared.$urls
            .receive(on: DispatchQueue.main)
            .sink { [weak self] urls in
                guard let self, !urls.isEmpty else { return }
                OpenURLRelay.shared.urls = []
                self.handleIncoming(urls)
            }
            .store(in: &cancellables)

        if engineAvailable {
            Task { [weak self] in
                guard let self else { return }
                let banner = await self.engine.fetchVersionBanner()
                self.engineBanner = banner
            }
        }
    }

    // MARK: - Opening archives

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Open Archive")
        panel.prompt = String(localized: "Open")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        guard panel.runModal() == .OK else { return }
        handleIncoming(panel.urls)
    }

    /// Files handed to the app: Finder "Open With", Dock drops, the open panel, window drops.
    func handleIncoming(_ urls: [URL]) {
        let fileURLs = urls.filter { $0.isFileURL }
        guard !fileURLs.isEmpty else { return }

        let archives = fileURLs.filter { ArchiveFileTypes.isArchive($0) && !isDirectory($0) }
        if archives.count == fileURLs.count {
            if archives.count == 1 {
                open(archives[0])
            } else {
                for url in archives { enqueueDefaultExtraction(for: url) }
            }
        } else {
            presentNewArchive(sources: fileURLs)
        }
    }

    func open(_ url: URL, password: String? = nil) {
        guard engineAvailable else {
            error = UserFacingError(title: String(localized: "Engine missing"), message: SevenZipError.engineNotFound.localizedDescription)
            return
        }
        loadTask?.cancel()
        isLoading = true
        loadingName = url.lastPathComponent
        archive = nil
        visibleEntries = []

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let info = try await self.engine.lister.list(url: url, password: password)
                guard !Task.isCancelled else { return }
                self.archive = info
                self.isLoading = false
                self.refreshVisibleEntries()
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
            } catch SevenZipError.wrongPassword {
                self.isLoading = false
                self.passwordPrompt = PasswordPrompt(
                    fileName: url.lastPathComponent,
                    isRetry: password != nil,
                    onSubmit: { [weak self] entered in
                        self?.passwordPrompt = nil
                        self?.open(url, password: entered)
                    },
                    onCancel: { [weak self] in
                        self?.passwordPrompt = nil
                    }
                )
            } catch SevenZipError.cancelled {
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.error = UserFacingError(title: String(localized: "Could not open archive"), message: error.localizedDescription)
            }
        }
    }

    func closeArchive() {
        loadTask?.cancel()
        archive = nil
        visibleEntries = []
        searchText = ""
        isLoading = false
    }

    func revealArchiveInFinder() {
        guard let archive else { return }
        NSWorkspace.shared.activateFileViewerSelecting([archive.url])
    }

    // MARK: - Extraction

    func extractCurrent(target: ExtractionTarget? = nil) {
        guard let archive else { return }
        let settings = AppSettings.current
        let resolvedTarget = target ?? settings.extractionTarget
        guard let destination = destination(for: archive.url, target: resolvedTarget, topLevelCount: archive.topLevelNames.count) else { return }

        if archive.hasEncryptedEntries, archive.password == nil {
            askPasswordThenExtract(archive: archive, destination: destination, overwrite: settings.overwritePolicy)
            return
        }
        enqueueExtraction(archiveURL: archive.url, destination: destination, overwrite: settings.overwritePolicy, password: archive.password, isNestedTar: archive.isNestedTar)
    }

    /// Batch extraction (several archives dropped at once): no listing step, safest defaults.
    private func enqueueDefaultExtraction(for url: URL) {
        let settings = AppSettings.current
        let target: ExtractionTarget = settings.extractionTarget == .here ? .here : .subfolder
        guard let destination = destination(for: url, target: target, topLevelCount: 2) else { return }
        let nested = ArchiveFileTypes.singleFileCompressors.contains(url.pathExtension.lowercased())
        enqueueExtraction(archiveURL: url, destination: destination, overwrite: settings.overwritePolicy, password: nil, isNestedTar: nested)
    }

    private func enqueueExtraction(archiveURL: URL, destination: URL, overwrite: OverwritePolicy, password: String?, isNestedTar: Bool) {
        let request = ExtractRequest(archiveURL: archiveURL, destination: destination, overwrite: overwrite, password: password, isNestedTar: isNestedTar)
        jobQueue.enqueue(.extract(request), title: archiveURL.lastPathComponent, detail: destination.path)
        showJobs = true
    }

    private func askPasswordThenExtract(archive: ArchiveInfo, destination: URL, overwrite: OverwritePolicy) {
        passwordPrompt = PasswordPrompt(
            fileName: archive.name,
            isRetry: false,
            onSubmit: { [weak self] entered in
                guard let self else { return }
                self.passwordPrompt = nil
                self.enqueueExtraction(archiveURL: archive.url, destination: destination, overwrite: overwrite, password: entered, isNestedTar: archive.isNestedTar)
            },
            onCancel: { [weak self] in self?.passwordPrompt = nil }
        )
    }

    func destination(for archiveURL: URL, target: ExtractionTarget, topLevelCount: Int) -> URL? {
        let parent = archiveURL.deletingLastPathComponent()
        let stem = ArchiveFileTypes.stem(for: archiveURL)
        switch target {
        case .here:
            return parent
        case .subfolder:
            return parent.appendingPathComponent(stem, isDirectory: true)
        case .smart:
            return topLevelCount == 1 ? parent : parent.appendingPathComponent(stem, isDirectory: true)
        case .ask:
            let panel = NSOpenPanel()
            panel.title = String(localized: "Choose Extraction Folder")
            panel.prompt = String(localized: "Extract")
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = parent
            guard panel.runModal() == .OK, let url = panel.url else { return nil }
            return url
        }
    }

    // MARK: - Creating archives

    func presentNewArchivePanel() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Files to Compress")
        panel.prompt = String(localized: "Add")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        presentNewArchive(sources: panel.urls)
    }

    func presentNewArchive(sources: [URL]) {
        guard !sources.isEmpty else { return }
        let settings = AppSettings.current
        let directory = sources[0].deletingLastPathComponent()
        let baseName: String
        if sources.count == 1 {
            baseName = ArchiveFileTypes.stem(for: sources[0])
        } else {
            let folderName = directory.lastPathComponent
            baseName = folderName.isEmpty || folderName == "/" ? String(localized: "Archive") : folderName
        }
        newArchiveDraft = NewArchiveDraft(
            sources: sources,
            directory: directory,
            baseName: baseName,
            format: settings.defaultFormat,
            level: settings.defaultLevel,
            encryptHeaders: settings.encryptHeadersByDefault,
            excludeMacMetadata: settings.excludeMacMetadata
        )
    }

    func createArchive(from draft: NewArchiveDraft, password: String?) {
        newArchiveDraft = nil
        let cleanName = Self.sanitizedFileName(draft.baseName)
        let fileName = (cleanName.isEmpty ? String(localized: "Archive") : cleanName) + "." + draft.format.fileExtension
        let destination = Self.nonCollidingURL(draft.directory.appendingPathComponent(fileName))
        let request = CreateRequest(
            sources: draft.sources,
            destination: destination,
            format: draft.format,
            level: draft.format.supportsCompressionLevel ? draft.level : .store,
            password: draft.format.supportsEncryption ? password : nil,
            encryptHeaders: draft.encryptHeaders,
            excludeMacMetadata: draft.excludeMacMetadata
        )
        jobQueue.enqueue(.create(request), title: destination.lastPathComponent, detail: draft.directory.path)
        showJobs = true
    }

    // MARK: - Job completion

    private func handleFinished(_ job: Job) {
        let settings = AppSettings.current
        switch job.state {
        case .finished, .finishedWithWarnings:
            guard let url = job.resultURL else { return }
            switch job.operation {
            case .extract(let request):
                if settings.revealAfterExtract { revealExtraction(request, at: url) }
            case .create:
                if settings.revealAfterCreate { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        case .failed(let message):
            if case .extract(let request) = job.operation, message == SevenZipError.wrongPassword.localizedDescription {
                passwordPrompt = PasswordPrompt(
                    fileName: request.archiveURL.lastPathComponent,
                    isRetry: request.password != nil,
                    onSubmit: { [weak self] entered in
                        guard let self else { return }
                        self.passwordPrompt = nil
                        self.jobQueue.remove(job.id)
                        self.enqueueExtraction(archiveURL: request.archiveURL, destination: request.destination, overwrite: request.overwrite, password: entered, isNestedTar: request.isNestedTar)
                    },
                    onCancel: { [weak self] in self?.passwordPrompt = nil }
                )
            }
        default:
            break
        }
    }

    private func revealExtraction(_ request: ExtractRequest, at destination: URL) {
        // Show the extracted content rather than the folder's parent when extracting "here".
        let parentOfArchive = request.archiveURL.deletingLastPathComponent().standardizedFileURL
        if destination.standardizedFileURL == parentOfArchive, let archive, archive.url == request.archiveURL, let first = archive.topLevelNames.first {
            NSWorkspace.shared.activateFileViewerSelecting([destination.appendingPathComponent(first)])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        }
    }

    // MARK: - Listing presentation

    private func refreshVisibleEntries() {
        guard let archive else {
            visibleEntries = []
            return
        }
        var entries = archive.entries
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            entries = entries.filter { $0.path.localizedCaseInsensitiveContains(query) }
        }
        visibleEntries = entries.sorted(using: sortOrder)
    }

    // MARK: - Helpers

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    static func sanitizedFileName(_ name: String) -> String {
        var cleaned = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        return cleaned
    }

    static func nonCollidingURL(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let directory = url.deletingLastPathComponent()
        let fileName = url.lastPathComponent
        let stem = ArchiveFileTypes.stem(for: url)
        let suffix = String(fileName.dropFirst(stem.count))
        var counter = 2
        while counter < 10_000 {
            let candidate = directory.appendingPathComponent("\(stem) \(counter)\(suffix)")
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            counter += 1
        }
        return url
    }
}

/// Buffers URLs handed to the app by Launch Services until the view model is ready to consume them.
@MainActor
final class OpenURLRelay: ObservableObject {
    static let shared = OpenURLRelay()
    @Published var urls: [URL] = []

    func deliver(_ newURLs: [URL]) {
        urls.append(contentsOf: newURLs)
    }
}
