// Sources/Views/JobsPanel.swift
import SwiftUI
import AppKit

struct JobsPanel: View {
    @EnvironmentObject private var queue: JobQueue

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tasks")
                    .font(.headline)
                if queue.activeCount > 0 {
                    Text("\(queue.activeCount) active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(String(localized: "Clear Finished")) {
                    queue.clearFinished()
                }
                .controlSize(.small)
                .disabled(!queue.jobs.contains { $0.state.isDone })
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(queue.jobs) { job in
                        JobRow(job: job)
                        Divider()
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct JobRow: View {
    @EnvironmentObject private var queue: JobQueue
    let job: Job

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: job.isExtract ? "arrow.down.doc" : "plus.square.on.square")
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(job.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(stateText)
                        .font(.caption)
                        .foregroundStyle(stateColor)
                }
                if job.state == .running {
                    ProgressView(value: job.progress)
                        .progressViewStyle(.linear)
                    Text(job.currentItem.isEmpty ? job.detail : job.currentItem)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(job.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if job.state == .running {
                Text(verbatim: "\(Int(job.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            trailingButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var trailingButtons: some View {
        switch job.state {
        case .queued, .running:
            Button {
                queue.cancel(job.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .help(Text("Cancel"))
        case .finished, .finishedWithWarnings:
            if let url = job.resultURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "magnifyingglass.circle")
                }
                .buttonStyle(.borderless)
                .help(Text("Show in Finder"))
            }
            removeButton
        case .failed, .cancelled:
            removeButton
        }
    }

    private var removeButton: some View {
        Button {
            queue.remove(job.id)
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help(Text("Remove from list"))
    }

    private var stateText: String {
        switch job.state {
        case .queued:
            return String(localized: "Waiting")
        case .running:
            return job.processedCount > 0 ? String(localized: "\(job.processedCount) items · \(job.elapsedText)") : String(localized: "Working… \(job.elapsedText)")
        case .finished:
            return String(localized: "Done in \(job.elapsedText)")
        case .finishedWithWarnings(let message):
            return String(localized: "Done with warnings: \(message)")
        case .failed(let message):
            return String(localized: "Failed: \(message)")
        case .cancelled:
            return String(localized: "Cancelled")
        }
    }

    private var stateColor: Color {
        switch job.state {
        case .queued: return .secondary
        case .running: return .accentColor
        case .finished: return .green
        case .finishedWithWarnings: return .orange
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    private var iconColor: Color {
        switch job.state {
        case .failed: return .red
        case .finishedWithWarnings: return .orange
        case .cancelled: return .secondary
        default: return job.isExtract ? .blue : .purple
        }
    }
}
