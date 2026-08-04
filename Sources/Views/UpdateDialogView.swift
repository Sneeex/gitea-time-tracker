import SwiftUI
import AppKit

public struct UpdateDialogView: View {
    @ObservedObject var updateChecker = UpdateChecker.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // MARK: - Header Icon & Badge
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "arrow.down.app.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Update verfügbar!")
                        .font(.headline)
                        .fontWeight(.bold)

                    if let release = updateChecker.latestRelease {
                        Text("Version v\(release.cleanVersion) ist jetzt verfügbar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Eine neue Version von Gitea Time Tracker ist bereit.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            // MARK: - Version Comparison Card
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aktuell")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("v\(updateChecker.currentVersion)")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .fontDesign(.monospaced)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Neu")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("v\(updateChecker.latestRelease?.cleanVersion ?? "–")")
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .fontDesign(.monospaced)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))

            // MARK: - Release Notes Preview
            if let body = updateChecker.latestRelease?.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Änderungen:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(body)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 110)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                }
            }

            // MARK: - Action Buttons
            VStack(spacing: 8) {
                Button {
                    if let release = updateChecker.latestRelease,
                       let url = URL(string: release.zipDownloadUrl ?? release.htmlUrl) {
                        NSWorkspace.shared.open(url)
                    } else if let fallbackUrl = URL(string: "https://github.com/Sneeex/gitea-time-tracker/releases/latest") {
                        NSWorkspace.shared.open(fallbackUrl)
                    }
                    updateChecker.dismissPopup()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Update herunterladen")
                            .fontWeight(.bold)
                    }
                    .font(.callout)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    updateChecker.dismissPopup()
                } label: {
                    Text("Später")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(width: 320)
    }
}
