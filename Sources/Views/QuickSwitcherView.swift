import SwiftUI

public struct QuickSwitcherView: View {
    @ObservedObject var timerService = TimerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var issues: [GiteaIssue] = []
    @State private var selectedIndex: Int = 0

    public init() {}

    private var filteredList: [GiteaIssue] {
        if searchText.isEmpty {
            return timerService.recentIssues
        }
        let query = searchText.lowercased()
        return issues.filter {
            $0.title.lowercased().contains(query) ||
            $0.formattedKey.lowercased().contains(query)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .font(.title3)
                    .foregroundColor(.blue)

                TextField("Quick Switch: Issue suchen...", text: $searchText)
                    .font(.title3)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color.primary.opacity(0.04))

            Divider()

            // List of matching issues
            if filteredList.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Keine passenden Issues")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(filteredList.enumerated()), id: \.element.id) { index, issue in
                                QuickSwitcherRow(
                                    issue: issue,
                                    isSelected: index == selectedIndex
                                ) {
                                    timerService.start(issue: issue)
                                    dismiss()
                                }
                                .id(index)
                            }
                        }
                        .padding(8)
                    }
                }
            }

            Divider()

            // Footer hint
            HStack {
                Text("⏎ Auswählen & Starten")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Esc Schließen")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))
        }
        .frame(width: 480, height: 320)
        .background(.ultraThinMaterial)
        .task {
            if let fetched = try? await GiteaAPIService.shared.fetchAssignedIssues() {
                self.issues = fetched
            }
        }
    }
}

struct QuickSwitcherRow: View {
    let issue: GiteaIssue
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(issue.formattedKey)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue.opacity(0.2)))
                    .foregroundColor(.blue)

                Text(issue.title)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }
}
