// Sources/Views/EmptyStateView.swift
import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject private var model: MainViewModel

    /// Compact strip layout used while the task list occupies the window.
    var compact: Bool = false

    var body: some View {
        if compact {
            compactLayout
        } else {
            fullLayout
        }
    }

    // MARK: - Full-size drop zone

    private var fullLayout: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(.secondary)
                Text("Drop an archive to open it, or drop files to compress them")
                    .font(.title3)
                    .foregroundStyle(.primary)
                Text("ZIP, 7z, RAR, TAR, GZ, XZ, BZ2, ZST, ISO, DMG, CAB and more are supported. Creates 7z, ZIP, TAR.GZ, TAR.XZ, TAR.BZ2 and TAR.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            HStack(spacing: 14) {
                openButton
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                newButton
                    .controlSize(.large)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Compact strip

    private var compactLayout: some View {
        HStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 34, weight: .thin))
                .foregroundStyle(.secondary)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("Drop an archive to open it, or drop files to compress them")
                    .font(.headline)
                Text("ZIP, 7z, RAR, TAR, GZ, XZ, BZ2, ZST, ISO, DMG, CAB and more are supported. Creates 7z, ZIP, TAR.GZ, TAR.XZ, TAR.BZ2 and TAR.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                openButton
                newButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .padding(12)
        )
    }

    // MARK: - Shared buttons

    private var openButton: some View {
        Button {
            model.presentOpenPanel()
        } label: {
            Label("Open Archive…", systemImage: "folder")
                .frame(minWidth: compact ? 0 : 150)
        }
    }

    private var newButton: some View {
        Button {
            model.presentNewArchivePanel()
        } label: {
            Label("New Archive…", systemImage: "plus.square.on.square")
                .frame(minWidth: compact ? 0 : 150)
        }
    }
}
