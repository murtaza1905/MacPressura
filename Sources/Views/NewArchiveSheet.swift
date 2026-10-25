// Sources/Views/NewArchiveSheet.swift
import SwiftUI
import AppKit

struct NewArchiveSheet: View {
    @EnvironmentObject private var model: MainViewModel

    @State private var draft: NewArchiveDraft
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var usePassword = false

    init(draft: NewArchiveDraft) {
        _draft = State(initialValue: draft)
    }

    private var sourcesSummary: String {
        if draft.sources.count == 1 {
            return draft.sources[0].lastPathComponent
        }
        return String(localized: "\(draft.sources.count) items")
    }

    private var outputFileName: String {
        let clean = MainViewModel.sanitizedFileName(draft.baseName)
        return (clean.isEmpty ? String(localized: "Archive") : clean) + "." + draft.format.fileExtension
    }

    private var passwordProblem: String? {
        guard usePassword, draft.format.supportsEncryption else { return nil }
        if password.isEmpty { return String(localized: "Enter a password.") }
        if password != passwordConfirm { return String(localized: "Passwords do not match.") }
        return nil
    }

    private var canCreate: Bool {
        !draft.sources.isEmpty && !MainViewModel.sanitizedFileName(draft.baseName).isEmpty && passwordProblem == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New Archive")
                .font(.title2.weight(.semibold))
                .padding(.bottom, 14)

            Form {
                Section {
                    LabeledContent(String(localized: "Content")) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sourcesSummary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if draft.sources.count > 1 {
                                Text(draft.sources.prefix(5).map { $0.lastPathComponent }.joined(separator: ", ") + (draft.sources.count > 5 ? "…" : ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }

                    LabeledContent(String(localized: "Name")) {
                        HStack(spacing: 6) {
                            TextField("", text: $draft.baseName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 260)
                            Text("." + draft.format.fileExtension)
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }
                    }

                    LabeledContent(String(localized: "Save to")) {
                        HStack(spacing: 8) {
                            Text(draft.directory.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Button(String(localized: "Choose…"), action: chooseDirectory)
                                .controlSize(.small)
                        }
                    }
                }

                Section {
                    Picker(String(localized: "Format"), selection: $draft.format) {
                        ForEach(ArchiveFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    if draft.format.supportsCompressionLevel {
                        Picker(String(localized: "Compression"), selection: $draft.level) {
                            ForEach(CompressionLevel.allCases) { level in
                                Text(level.localizedName).tag(level)
                            }
                        }
                    }

                    Toggle(String(localized: "Skip macOS metadata (.DS_Store, __MACOSX, ._* files)"), isOn: $draft.excludeMacMetadata)
                }

                Section {
                    if draft.format.supportsEncryption {
                        Toggle(String(localized: "Protect with a password (AES-256)"), isOn: $usePassword)
                        if usePassword {
                            SecureField(String(localized: "Password"), text: $password)
                            SecureField(String(localized: "Confirm password"), text: $passwordConfirm)
                            if draft.format.supportsHeaderEncryption {
                                Toggle(String(localized: "Also hide file names (encrypt headers)"), isOn: $draft.encryptHeaders)
                            }
                            if let passwordProblem {
                                Text(passwordProblem)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    } else {
                        Text("Password protection is available for 7z and ZIP archives.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(height: 440)

            HStack {
                Text(outputFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(String(localized: "Cancel"), role: .cancel) {
                    model.newArchiveDraft = nil
                }
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "Create")) {
                    model.createArchive(from: draft, password: usePassword && draft.format.supportsEncryption ? password : nil)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
            .padding(.top, 10)
        }
        .padding(22)
        .frame(width: 560)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose Folder")
        panel.prompt = String(localized: "Choose")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = draft.directory
        if panel.runModal() == .OK, let url = panel.url {
            draft.directory = url
        }
    }
}
