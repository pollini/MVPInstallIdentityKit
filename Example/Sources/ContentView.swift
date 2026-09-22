import SwiftUI
import MVPInstallIdentityKit

/// Manual verification harness for `MVPInstallIdentityKit`.
///
/// Unit tests can't exercise the real Keychain (see the package README), so
/// this is the only way to actually confirm the reinstall / device-migration
/// / iCloud-sync behavior: pick an accessibility mode, hit Resolve, then
/// delete + reinstall the app (or restore this device from a backup onto a
/// new one) and Resolve again to see whether the same `id` comes back.
struct ContentView: View {
    @State private var accessibility: KeychainAccessibility = .afterFirstUnlockThisDeviceOnly
    @State private var info: InstallInfo?
    @State private var errorMessage: String?

    private var identifier: InstallIdentifier {
        InstallIdentifier(accessibility: accessibility)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Accessibility", selection: $accessibility) {
                        Text("This device only").tag(KeychainAccessibility.afterFirstUnlockThisDeviceOnly)
                        Text("Migratable").tag(KeychainAccessibility.afterFirstUnlockMigratable)
                        Text("Synchronizable").tag(KeychainAccessibility.afterFirstUnlockSynchronizable)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Accessibility mode")
                } footer: {
                    Text("Changes which Keychain item Resolve reads/writes next. Pick a mode, tap Resolve, then delete + reinstall the app (or set up a new device from a backup of this one) to see whether the same ID comes back.")
                }

                if let info {
                    Section("Result") {
                        LabeledContent("ID", value: info.id.uuidString)
                        LabeledContent("First seen", value: info.firstSeenDate.formatted(date: .abbreviated, time: .standard))
                        LabeledContent("First launch ever") {
                            Text(info.isFirstLaunchEver ? "Yes" : "No")
                                .foregroundStyle(info.isFirstLaunchEver ? .green : .secondary)
                        }
                    }
                }

                if let errorMessage {
                    Section("Error") {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Resolve") { resolve() }
                    Button("Reset (debug only)", role: .destructive) { reset() }
                } footer: {
                    Text("Reset deletes the stored identity so the next Resolve looks like a first-ever launch again. Never call this in a shipped code path.")
                }
            }
            .navigationTitle("MVPInstallIdentityKit")
            .onAppear { resolve() }
        }
    }

    private func resolve() {
        errorMessage = nil
        do {
            info = try identifier.resolve()
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func reset() {
        errorMessage = nil
        do {
            try identifier.reset()
            info = nil
        } catch {
            errorMessage = "\(error)"
        }
    }
}

#Preview {
    ContentView()
}
