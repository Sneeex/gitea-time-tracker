import SwiftUI
import AppKit

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
            $0.formattedKey.lowercased().contains(query) ||
            $0.repoName.lowercased().contains(query)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .font(.title3)
                    .foregroundColor(.blue)

                TextField("Quick Switch: Issue oder PR suchen...", text: $searchText)
                    .font(.title3)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        selectCurrentIndex()
                    }

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
                    Text("Keine passenden Issues oder PRs")
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
                                    closeWindow()
                                }
                                .id(index)
                            }
                        }
                        .padding(8)
                    }
                }
            }

            Divider()

            // Footer hint & hidden escape action
            HStack {
                Text("⏎ Auswählen & Starten")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Esc Schließen")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Hidden Escape Button to catch Esc key press globally in window
                Button("") {
                    closeWindow()
                }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)

                // Hidden Default Action for Return key
                Button("") {
                    selectCurrentIndex()
                }
                .keyboardShortcut(.defaultAction)
                .opacity(0)
                .frame(width: 0, height: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))
        }
        .frame(width: 500, height: 340)
        .background(.ultraThinMaterial)
        .onExitCommand {
            closeWindow()
        }
        .task {
            if let fetched = try? await GiteaAPIService.shared.fetchAssignedIssues() {
                self.issues = fetched
            }
        }
    }

    private func selectCurrentIndex() {
        let list = filteredList
        guard !list.isEmpty, selectedIndex >= 0, selectedIndex < list.count else { return }
        let selected = list[selectedIndex]
        timerService.start(issue: selected)
        closeWindow()
    }

    private func closeWindow() {
        dismiss()
        NSApp.keyWindow?.close()
    }
}

struct QuickSwitcherRow: View {
    let issue: GiteaIssue
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Issue vs PR Badge & Icon
                HStack(spacing: 4) {
                    Image(systemName: issue.isPullRequest ? "arrow.triangle.pull" : "exclamationmark.circle")
                        .font(.caption)
                    Text(issue.isPullRequest ? "PR \(issue.formattedKey)" : issue.formattedKey)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(issue.isPullRequest ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                )
                .foregroundColor(issue.isPullRequest ? .purple : .blue)

                // Title & Repo
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.title)
                        .font(.body)
                        .lineLimit(1)
                    if !issue.repoName.isEmpty && issue.repoName != "Unknown" {
                        Text(issue.repoName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(issue.isPullRequest ? .purple : .blue)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? (issue.isPullRequest ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15)) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }
}
