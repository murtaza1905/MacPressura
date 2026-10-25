// Sources/Views/PasswordSheet.swift
import SwiftUI

struct PasswordSheet: View {
    let prompt: PasswordPrompt
    @State private var password = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Password required")
                        .font(.headline)
                    Text(prompt.fileName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if prompt.isRetry {
                Text("The password was not accepted. Try again.")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            SecureField(String(localized: "Password"), text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(submit)

            HStack {
                Spacer()
                Button(String(localized: "Cancel"), role: .cancel) {
                    prompt.onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "Unlock"), action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 420)
        .onAppear { focused = true }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        prompt.onSubmit(password)
    }
}
