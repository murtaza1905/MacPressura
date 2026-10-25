// Sources/Views/ContentView.swift
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: MainViewModel
    @EnvironmentObject private var queue: JobQueue

    /// Task list is visible and has something to show.
    private var jobsVisible: Bool {
        model.showJobs && !queue.jobs.isEmpty
    }

    /// With no archive open, the task list takes over the window and the drop zone shrinks to a strip.
    private var compactDropZone: Bool {
        jobsVisible && model.archive == nil && !model.isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            if !model.engineAvailable {
                engineMissingBanner
            }

            if compactDropZone {
                mainArea
                    .frame(maxWidth: .infinity)
                    .frame(height: 132)
            } else {
                mainArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if jobsVisible {
                Divider()
                if compactDropZone {
                    JobsPanel()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    JobsPanel()
                        .frame(height: 200)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(dropOverlay)
        .dropDestination(for: URL.self) { urls, _ in
            model.handleIncoming(urls)
            return true
        } isTargeted: { targeted in
            model.isDropTargeted = targeted
        }
        .toolbar { toolbarContent }
        .navigationTitle(model.archive?.name ?? "MacPressura")
        .navigationSubtitle(subtitle)
        .sheet(item: $model.passwordPrompt) { prompt in
            PasswordSheet(prompt: prompt)
        }
        .sheet(item: $model.newArchiveDraft) { draft in
            NewArchiveSheet(draft: draft)
                .environmentObject(model)
        }
        .alert(item: $model.error) { error in
            Alert(title: Text(error.title), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var mainArea: some View {
        if model.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Reading \(model.loadingName)…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.archive != nil {
            ArchiveView()
        } else {
            EmptyStateView(compact: compactDropZone)
        }
    }

    private var subtitle: String {
        guard let archive = model.archive else { return "" }
        let files = String(localized: "\(archive.fileCount) files")
        let folders = String(localized: "\(archive.folderCount) folders")
        return "\(archive.type.uppercased()) · \(files), \(folders) · \(archive.formattedTotalSize)"
    }

    @ViewBuilder
    private var dropOverlay: some View {
        if model.isDropTargeted {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
                .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(8)
                .allowsHitTesting(false)
        }
    }

    private var engineMissingBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("The 7-Zip engine (7zz) is missing from the app bundle. Run ./build.sh again to rebuild.")
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.12))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                model.presentOpenPanel()
            } label: {
                Label("Open", systemImage: "folder")
            }
            .help(Text("Open an archive (⌘O)"))

            Button {
                model.presentNewArchivePanel()
            } label: {
                Label("New Archive", systemImage: "plus.square.on.square")
            }
            .help(Text("Create a new archive (⌘N)"))
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if model.archive != nil {
                Menu {
                    Button(String(localized: "Extract Here")) { model.extractCurrent(target: .here) }
                    Button(String(localized: "Extract to Folder Named After Archive")) { model.extractCurrent(target: .subfolder) }
                    Button(String(localized: "Extract to…")) { model.extractCurrent(target: .ask) }
                } label: {
                    Label("Extract", systemImage: "arrow.down.doc")
                } primaryAction: {
                    model.extractCurrent()
                }
                .help(Text("Extract with the default setting (⌘E); use the menu for other targets"))

                Button {
                    model.closeArchive()
                } label: {
                    Label("Close", systemImage: "xmark.circle")
                }
                .help(Text("Close this archive"))
            }

            Button {
                model.showJobs.toggle()
            } label: {
                Label("Tasks", systemImage: queue.isBusy ? "arrow.triangle.2.circlepath.circle.fill" : "list.bullet.rectangle")
            }
            .help(Text("Show or hide the task list (⌘J)"))
        }
    }
}
