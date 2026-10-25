// Sources/Views/EmptyStateView.swift
import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject private var model: MainViewModel

    var body: some View {
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
                Button {
                    model.presentOpenPanel()
                } label: {
                    Label("Open Archive…", systemImage: "folder")
                        .frame(minWidth: 150)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Button {
                    model.presentNewArchivePanel()
                } label: {
                    Label("New Archive…", systemImage: "plus.square.on.square")
                        .frame(minWidth: 150)
                }
                .controlSize(.large)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
