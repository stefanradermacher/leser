// Copyright 2026 Stefan Radermacher
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI

/// Bar at the top of a document window when a changed file is encrypted and needs its password
/// again. The version on screen stays readable until the new one is unlocked.
struct LockedChangeBanner: View {
    let change: LockedChange
    let state: ReaderState

    @State private var asksPassword = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.doc")
                .foregroundStyle(.secondary)
            Text("„\(change.name)“ wurde geändert und ist durch ein Passwort geschützt.")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button("Passwort eingeben …") { asksPassword = true }
                .popover(isPresented: $asksPassword, arrowEdge: .bottom) {
                    ChangePasswordField { password in
                        state.unlockChange(at: change.url, password: password)
                    }
                }
            Button("Alte Fassung behalten") { state.keepCurrentVersion(of: change.url) }
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// Password field in the popover of `LockedChangeBanner`. The password lives only as long as
/// the field needs it and is cleared after every attempt.
private struct ChangePasswordField: View {
    let unlock: (String) -> Bool

    @State private var password = ""
    @State private var failed = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SecureField("Passwort", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .focused($focused)
                    .onSubmit(submit)
                Button("Entsperren", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
            if failed {
                Text("Das Passwort ist nicht korrekt.")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .onAppear { focused = true }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        failed = !unlock(password)
        password = ""
    }
}
