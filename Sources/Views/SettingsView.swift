import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject var syncManager = OfflineSyncManager.shared
    @ObservedObject var updateChecker = UpdateChecker.shared
    @ObservedObject var gitWatcher = GitWatcherService.shared
    @ObservedObject var globalHotkey = GlobalHotkeyService.shared

    @State private var serverURL: String = ""
    @State private var token: String = ""
    @State private var showToken: Bool = false

    @State private var isTesting: Bool = false
    @State private var testStatus: String?
    @State private var isSuccess: Bool = false
    @State private var authenticatedUser: GiteaUser?

    @State private var isAutostartEnabled: Bool = false

    public init() {}

    public var cleanedURLString: String {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            return "https://\(trimmed)"
        }
        return trimmed
    }

    private func selectGitFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Git-Ordner auswählen"
        if panel.runModal() == .OK, let url = panel.url {
            gitWatcher.addFolder(url.path)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - Server Configuration
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gitea Server URL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.secondary)
                        TextField("https://git.dein-domain.de", text: $serverURL)
                            .textFieldStyle(.plain)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                }

                // MARK: - Personal Access Token (PAT)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Personal Access Token (PAT)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                        if !cleanedURLString.isEmpty, let tokenURL = URL(string: "\(cleanedURLString)/user/settings/applications") {
                            Link("Token in Gitea erstellen ↗", destination: tokenURL)
                                .font(.caption2)
                        }
                    }

                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.secondary)

                        if showToken {
                            TextField("Dein Gitea PAT Token", text: $token)
                                .textFieldStyle(.plain)
                        } else {
                            SecureField("Dein Gitea PAT Token", text: $token)
                                .textFieldStyle(.plain)
                        }

                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))

                    Text("Erforderliche Gitea-Token Rechte:\n• `issue` (Lesen & Schreiben - für Zeitbuchung)\n• `repository` (Lesen - für Repository-Liste)\n• `user` (Lesen - für 'Mir zugewiesen' Filter)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // MARK: - Test & Save Button (High Contrast AAA)
                Button {
                    saveAndTestConnection()
                } label: {
                    HStack(spacing: 8) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                            Text("Verbindung testen & Speichern")
                                .fontWeight(.bold)
                        }
                    }
                    .font(.callout)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill((serverURL.isEmpty || token.isEmpty || isTesting) ? Color.gray.opacity(0.4) : Color.blue)
                    )
                }
                .buttonStyle(.plain)
                .disabled(serverURL.isEmpty || token.isEmpty || isTesting)

                // Test Feedback Banner
                if let status = testStatus {
                    HStack(spacing: 8) {
                        Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isSuccess ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            if let user = authenticatedUser {
                                Text("Angemeldet als **@\(user.username)** (\(user.fullName ?? ""))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSuccess ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    )
                }

                Divider()
                    .padding(.vertical, 4)

                // MARK: - Autostart & System-Integration Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("System-Integration & Kurzbefehle")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    Toggle("Beim Mac-Start automatisch öffnen", isOn: $isAutostartEnabled)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .onChange(of: isAutostartEnabled) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print("Autostart setting failed: \(error)")
                            }
                        }

                    Divider()

                    // Global Hotkey Toggle & Custom Recorder
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Globaler Schnellzugriff", isOn: $globalHotkey.isEnabled)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Öffnet die Gitea Quick Switcher Konsole von überall in macOS.")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if globalHotkey.isEnabled {
                            HStack {
                                Text("Tastaturkürzel:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()

                                Button {
                                    if globalHotkey.isRecording {
                                        globalHotkey.stopRecording()
                                    } else {
                                        globalHotkey.startRecording()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: globalHotkey.isRecording ? "record.circle.fill" : "keyboard")
                                            .foregroundColor(globalHotkey.isRecording ? .red : .blue)
                                        Text(globalHotkey.isRecording ? "Taste drücken..." : globalHotkey.displayString)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(globalHotkey.isRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.12))
                                    )
                                }
                                .buttonStyle(.plain)

                                if globalHotkey.displayString != GlobalHotkeyService.defaultDisplayString {
                                    Button {
                                        globalHotkey.resetToDefault()
                                    } label: {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Auf Standard (⌥ ⇧ G) zurücksetzen")
                                }
                            }
                            .padding(.top, 2)
                        }
                    }

                    Divider()

                    // Git Auto-Tracking & Notifications
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Git-Branch Wechsel automatisch erkennen", isOn: $gitWatcher.isEnabled)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Erkennt Branch-Namen mit Issue-Nummer (z.B. `feature/#42-auth`) und bietet per Benachrichtigung 1-Click Zeiterfassung an.")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        HStack {
                            Button {
                                NotificationService.shared.requestAuthorization()
                                NotificationService.shared.sendTestNotification()
                            } label: {
                                Label("Test-Benachrichtigung senden", systemImage: "bell.badge")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }

                        if gitWatcher.isEnabled {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Überwachte Git-Ordner (\(gitWatcher.watchedFolderPaths.count))")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Button(action: selectGitFolder) {
                                        Label("Ordner hinzufügen", systemImage: "folder.badge.plus")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                }

                                if gitWatcher.watchedFolderPaths.isEmpty {
                                    Text("Noch keine Ordner hinzugefügt.")
                                        .font(.caption2)
                                        .italic()
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(gitWatcher.watchedFolderPaths, id: \.self) { path in
                                        HStack {
                                            Image(systemName: "folder.fill")
                                                .foregroundColor(.blue)
                                            Text(path)
                                                .font(.caption2)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Spacer()
                                            Button {
                                                gitWatcher.removeFolder(path)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(6)
                                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

                Divider()
                    .padding(.vertical, 4)

                // MARK: - App Updates Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("App-Updates (GitHub)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Installierte Version")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("v\(updateChecker.currentVersion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            Task {
                                await updateChecker.checkForUpdates(isManualCheck: true)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if updateChecker.isChecking {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Nach Updates suchen")
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(updateChecker.isChecking)
                    }

                    Toggle("Beim Start automatisch nach Updates suchen", isOn: Binding(
                        get: { updateChecker.isAutoCheckEnabled },
                        set: { updateChecker.isAutoCheckEnabled = $0 }
                    ))
                    .font(.subheadline)
                    .fontWeight(.medium)

                    if let msg = updateChecker.statusMessage {
                        HStack(spacing: 6) {
                            Image(systemName: updateChecker.isUpdateAvailable ? "sparkles" : "checkmark.circle.fill")
                                .foregroundColor(updateChecker.isUpdateAvailable ? .blue : .green)
                            Text(msg)
                                .font(.caption2)
                                .foregroundColor(updateChecker.isUpdateAvailable ? .blue : .secondary)
                        }
                    } else if let err = updateChecker.lastCheckError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

                Divider()
                    .padding(.vertical, 4)

                // MARK: - Offline Sync Queue Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Offline-Warteschlange")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(syncManager.pendingEntries.count) Ausstehende Einträge")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Zeiteinträge, die offline erfasst wurden.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        Button {
                            Task {
                                await syncManager.syncPendingEntries()
                            }
                        } label: {
                            Label("Jetzt Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .disabled(syncManager.pendingEntries.isEmpty || syncManager.isSyncing)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
                }
            }
            .padding()
        }
        .onAppear {
            self.serverURL = KeychainService.shared.getServerURL()
            self.token = KeychainService.shared.getToken() ?? ""
            self.isAutostartEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }

    private func saveAndTestConnection() {
        isTesting = true
        testStatus = nil

        let targetURL = cleanedURLString
        KeychainService.shared.saveServerURL(targetURL)
        _ = KeychainService.shared.saveToken(token)

        Task {
            if let user = await GiteaAPIService.shared.getCurrentUser() {
                self.isSuccess = true
                self.authenticatedUser = user
                self.testStatus = "Verbindung erfolgreich hergestellt!"
            } else {
                self.isSuccess = false
                self.authenticatedUser = nil
                self.testStatus = "Verbindung fehlgeschlagen. Prüfe URL und Token."
            }
            self.isTesting = false
        }
    }
}
