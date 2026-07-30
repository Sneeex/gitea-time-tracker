import SwiftUI

public enum NavigationTab: String, CaseIterable, Identifiable {
    case timer = "Stoppuhr"
    case issues = "Issues"
    case settings = "Einstellungen"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .timer: return "stopwatch.fill"
        case .issues: return "list.bullet.rectangle.portrait.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MenuBarView: View {
    @ObservedObject var timerService = TimerService.shared
    @ObservedObject var syncManager = OfflineSyncManager.shared

    @State private var activeTab: NavigationTab = .timer

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header Tab Bar
            HStack(spacing: 4) {
                ForEach(NavigationTab.allCases) { tab in
                    Button {
                        activeTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.headline)
                            Text(tab.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(activeTab == tab ? Color.blue.opacity(0.18) : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(activeTab == tab ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // MARK: - Active Tab Content (Solid, non-flashing container)
            ZStack {
                switch activeTab {
                case .timer:
                    TimerSectionView()
                case .issues:
                    IssuePickerView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // MARK: - Footer Status Bar
            HStack {
                // Connection Indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(KeychainService.shared.getToken() != nil ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(KeychainService.shared.getToken() != nil ? "Gitea Bereit" : "Token fehlt")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !syncManager.pendingEntries.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "icloud.and.arrow.up")
                            .foregroundColor(.orange)
                        Text("\(syncManager.pendingEntries.count) Offline")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    .padding(.trailing, 8)
                }

                Button("Beenden") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .frame(width: 380, height: 420)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
    }
}
