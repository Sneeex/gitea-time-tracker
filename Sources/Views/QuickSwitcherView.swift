import SwiftUI
import AppKit

public struct QuickSwitcherView: View {
    @ObservedObject var timerService = TimerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var issues: [GiteaIssue] = []
    @State private var isLoading: Bool = true
    @State private var selectedIndex: Int = 0

    public init() {}

    private var filteredList: [GiteaIssue] {
        let source: [GiteaIssue] = issues

        var result: [GiteaIssue] = []
        var seenIDs = Set<Int>()

        let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for item in source {
            if !seenIDs.contains(item.id) {
                if query.isEmpty ||
                   item.title.lowercased().contains(query) ||
                   item.formattedKey.lowercased().contains(query) ||
                   item.repoName.lowercased().contains(query) {
                    seenIDs.insert(item.id)
                    result.append(item)
                }
            }
        }
        return result
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Active Timer Header Controls (if active issue selected or timer running)
            if let activeIssue = timerService.activeIssue {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        // Issue/PR indicator & Title
                        HStack(spacing: 4) {
                            Image(systemName: activeIssue.isPullRequest ? "arrow.triangle.pull" : "exclamationmark.circle")
                            Text(activeIssue.isPullRequest ? "PR \(activeIssue.formattedKey)" : activeIssue.formattedKey)
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(activeIssue.isPullRequest ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2)))
                        .foregroundColor(activeIssue.isPullRequest ? .purple : .blue)

                        Text(activeIssue.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        Spacer()

                        // Monospace Timer Readout
                        Text(SmartTimeParser.formatTimerString(timerService.elapsedSeconds))
                            .font(.system(.title3, design: .monospaced, weight: .bold))
                            .foregroundColor(timerService.state == .running ? .green : (timerService.state == .paused ? .orange : .primary))
                    }

                    // Action Controls Bar
                    HStack(spacing: 8) {
                        // Pause / Resume Button
                        if timerService.state == .running {
                            Button {
                                timerService.pause()
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        } else {
                            Button {
                                if timerService.state == .paused {
                                    timerService.resume()
                                } else {
                                    timerService.start(issue: activeIssue)
                                }
                            } label: {
                                Label(timerService.state == .paused ? "Weiter" : "Start", systemImage: "play.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }

                        // Log Time Button
                        Button {
                            Task {
                                await timerService.stopAndLogTime()
                            }
                        } label: {
                            if timerService.isSubmitting {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Buchen", systemImage: "arrow.up.circle.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(timerService.elapsedSeconds == 0 || timerService.isSubmitting)

                        // Quick Add Chips
                        Button("+15m") { timerService.addSeconds(15 * 60) }
                            .buttonStyle(.bordered)
                            .font(.caption2)
                        Button("+30m") { timerService.addSeconds(30 * 60) }
                            .buttonStyle(.bordered)
                            .font(.caption2)

                        Spacer()

                        // Discard / Stop Button
                        Button {
                            timerService.stop()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Timer abbrechen")
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.06))

                Divider()
            }

            // MARK: - Search Input Header
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
                    .onChange(of: searchText) { _, _ in
                        selectedIndex = 0
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
            .padding(12)
            .background(Color.primary.opacity(0.03))

            Divider()

            // MARK: - List of matching issues
            let list = filteredList
            if isLoading && issues.isEmpty {
                QuickSwitcherSkeletonView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if list.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Keine passenden Issues oder PRs")
                        .foregroundColor(.secondary)

                    if let suggestion = suggestedCorrection {
                        Button {
                            searchText = suggestion
                        } label: {
                            HStack(spacing: 4) {
                                Text("Meintest du")
                                Text("„\(suggestion)“")
                                    .fontWeight(.medium)
                                    .underline()
                                Text("?")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(list.enumerated()), id: \.offset) { index, issue in
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
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // MARK: - Footer hint & Keyboard navigation shortcuts
            HStack {
                Text("↑↓ Navigieren  •  ⏎ Starten")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Esc Schließen")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Hidden Escape & Return Key Shortcuts
                Group {
                    Button("") { closeWindow() }
                        .keyboardShortcut(.cancelAction)
                    Button("") { selectCurrentIndex() }
                        .keyboardShortcut(.defaultAction)
                }
                .hidden()
                .frame(width: 0, height: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.03))
        }
        .frame(width: 520, height: timerService.activeIssue != nil ? 440 : 360)
        .background(.ultraThinMaterial)
        .onExitCommand {
            closeWindow()
        }
        .onAppear {
            selectedIndex = 0
            setupKeyMonitor()
            configureWindowLevel()
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .task {
            isLoading = issues.isEmpty
            if let fetched = try? await GiteaAPIService.shared.fetchAssignedIssues() {
                self.issues = fetched
            }
            isLoading = false
        }
    }

    @State private var keyMonitor: Any?

    private func setupKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let count = filteredList.count
            guard count > 0 else { return event }

            switch Int(event.keyCode) {
            case 125: // Down Arrow
                self.selectedIndex = min(count - 1, self.selectedIndex + 1)
                return nil
            case 126: // Up Arrow
                self.selectedIndex = max(0, self.selectedIndex - 1)
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func selectCurrentIndex() {
        let list = filteredList
        guard !list.isEmpty, selectedIndex >= 0, selectedIndex < list.count else { return }
        let selected = list[selectedIndex]
        timerService.start(issue: selected)
        closeWindow()
    }

    private func configureWindowLevel() {
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.identifier?.rawValue == "quick-switcher" || $0.title == "Gitea Quick Switcher" }) {
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            }
        }
    }

    private var suggestedCorrection: String? {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, filteredList.isEmpty else { return nil }

        var bestWord: String?
        var minDistance = Int.max

        for issue in issues {
            let textToScan = "\(issue.title) \(issue.repoName) \(issue.formattedKey)"
            let words = textToScan.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }

            for word in words {
                let lowerWord = word.lowercased()
                if lowerWord == query || lowerWord.contains(query) || query.contains(lowerWord) { continue }

                let dist = levenshteinDistance(query, lowerWord)
                let maxAllowedDist = query.count <= 4 ? 1 : (query.count <= 7 ? 2 : 3)

                if dist <= maxAllowedDist && dist < minDistance {
                    minDistance = dist
                    bestWord = word
                }
            }
        }
        return bestWord
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        var dist = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)

        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                dist[i][j] = min(
                    dist[i - 1][j] + 1,
                    dist[i][j - 1] + 1,
                    dist[i - 1][j - 1] + cost
                )
            }
        }
        return dist[a.count][b.count]
    }

    private func closeWindow() {
        removeKeyMonitor()
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
                    .fill(isSelected ? (issue.isPullRequest ? Color.purple.opacity(0.22) : Color.blue.opacity(0.22)) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? (issue.isPullRequest ? Color.purple : Color.blue) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skeleton Shimmer Components
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.6

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: geo.size.width * phase)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

struct QuickSwitcherSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 10) {
                        // Badge placeholder
                        Capsule()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 56, height: 22)

                        // Title & Subtitle placeholders
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.12))
                                .frame(height: 15)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.06))
                                .frame(width: 80, height: 10)
                        }

                        Spacer()

                        // Button placeholder
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 20, height: 20)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.04))
                    )
                }
            }
            .padding(8)
        }
        .shimmering()
    }
}
