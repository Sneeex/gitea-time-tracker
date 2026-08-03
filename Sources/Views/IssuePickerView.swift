import SwiftUI

public enum IssueFilterTab: String, CaseIterable, Identifiable {
    case all = "Alle"
    case assigned = "Zugewiesen"
    case favorites = "Favoriten"
    case recents = "Zuletzt"

    public var id: String { rawValue }
}

public enum IssueTypeFilter: String, CaseIterable, Identifiable {
    case all = "Alle Typen"
    case issuesOnly = "Nur Issues"
    case prsOnly = "Nur PRs"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .issuesOnly: return "exclamationmark.circle"
        case .prsOnly: return "arrow.triangle.pull"
        }
    }
}

public struct IssuePickerView: View {
    @ObservedObject var timerService = TimerService.shared

    @State private var repositories: [GiteaRepository] = []
    @AppStorage("gitea_selected_repo_fullname") private var selectedRepoFullName: String = "ALL_REPOS"
    @AppStorage("gitea_selected_filter_tab") private var selectedTabRaw: String = IssueFilterTab.all.rawValue
    @AppStorage("gitea_selected_type_filter") private var typeFilterRaw: String = IssueTypeFilter.all.rawValue

    private var selectedTabBinding: Binding<IssueFilterTab> {
        Binding(
            get: { IssueFilterTab(rawValue: selectedTabRaw) ?? .all },
            set: { selectedTabRaw = $0.rawValue }
        )
    }

    private var typeFilterBinding: Binding<IssueTypeFilter> {
        Binding(
            get: { IssueTypeFilter(rawValue: typeFilterRaw) ?? .all },
            set: { typeFilterRaw = $0.rawValue }
        )
    }

    private var selectedTab: IssueFilterTab {
        IssueFilterTab(rawValue: selectedTabRaw) ?? .all
    }

    private var typeFilter: IssueTypeFilter {
        IssueTypeFilter(rawValue: typeFilterRaw) ?? .all
    }

    @State private var searchText: String = ""
    @State private var issues: [GiteaIssue] = []
    @State private var currentUsername: String?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    public init() {}

    public var filteredIssues: [GiteaIssue] {
        var baseList: [GiteaIssue] = issues

        // 1. Repository Filter
        if selectedRepoFullName != "ALL_REPOS" {
            baseList = baseList.filter { issue in
                if let repo = issue.repository {
                    let fullName = repo.fullName ?? "\(repo.ownerName)/\(repo.name)"
                    return fullName.lowercased() == selectedRepoFullName.lowercased()
                }
                return true
            }
        }

        // 2. Type Filter (Issues vs PRs)
        switch typeFilter {
        case .all:
            break
        case .issuesOnly:
            baseList = baseList.filter { !$0.isPullRequest }
        case .prsOnly:
            baseList = baseList.filter { $0.isPullRequest }
        }

        // 3. Tab Filter
        switch selectedTab {
        case .all:
            break
        case .assigned:
            if let user = currentUsername?.lowercased(), !user.isEmpty {
                baseList = baseList.filter { issue in
                    guard let assignee = issue.assignee else { return false }
                    return assignee.username.lowercased() == user
                }
            } else {
                baseList = baseList.filter { $0.assignee != nil }
            }
        case .favorites:
            baseList = baseList.filter { timerService.isFavorite($0) }
        case .recents:
            baseList = timerService.recentIssues
        }

        // 4. Search Text Filter
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return baseList
        }

        let query = searchText.lowercased()
        return baseList.filter { issue in
            issue.title.lowercased().contains(query) ||
            issue.formattedKey.lowercased().contains(query) ||
            (issue.repository?.name.lowercased().contains(query) ?? false)
        }
    }

    public var availableRepositories: [GiteaRepository] {
        var repoMap: [String: GiteaRepository] = [:]

        // 1. Repos from user repos API
        for repo in repositories {
            let key = (repo.fullName ?? "\(repo.ownerName)/\(repo.name)").lowercased()
            repoMap[key] = repo
        }

        // 2. Repos from fetched issues (ensures assigned repos like sstk-semesterprojekt appear)
        for issue in issues {
            if let repo = issue.repository {
                let key = (repo.fullName ?? "\(repo.ownerName)/\(repo.name)").lowercased()
                if repoMap[key] == nil {
                    repoMap[key] = repo
                }
            }
        }

        return repoMap.values.sorted {
            ($0.fullName ?? $0.name).lowercased() < ($1.fullName ?? $1.name).lowercased()
        }
    }

    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Repository Dropdown Selector
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text("Repo:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedRepoFullName) {
                    Text("Alle Repositories").tag("ALL_REPOS")
                    ForEach(availableRepositories, id: \.id) { repo in
                        let label = repo.fullName ?? "\(repo.ownerName)/\(repo.name)"
                        Text(label).tag(label)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedRepoFullName) { _, _ in
                    Task { await loadIssues() }
                }

                Spacer()

                // Direct Type Filter Dropdown (Alle / Nur Issues / Nur PRs)
                Picker("Typ:", selection: typeFilterBinding) {
                    ForEach(IssueTypeFilter.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

            // MARK: - Search Bar & Refresh
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Suchen...", text: $searchText)
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
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))

                Button {
                    Task { await loadIssues() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                .help("Issues neu laden")
            }

            // MARK: - Filter Segmented Picker
            Picker("Filter", selection: selectedTabBinding) {
                ForEach(IssueFilterTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            // MARK: - Error Banner
            if let err = errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.callout)
                    
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
            }

            // MARK: - Issues List Container (Stable Non-Flashing Layout)
            ZStack {
                if filteredIssues.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        if isLoading {
                            ProgressView("Lade Issues von Gitea...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "tray")
                                .font(.system(size: 30))
                                .foregroundColor(.secondary)
                            Text("Keine Treffer gefunden")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text(selectedTab == .assigned ? "Dir (@\(currentUsername ?? "user")) sind aktuell keine Issues oder PRs zugewiesen." : "Keine Einträge für den ausgewählten Filter.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)

                            Button("Issues neu laden") {
                                Task { await loadIssues() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 4)
                        }
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredIssues) { issue in
                                IssueCardView(issue: issue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .opacity(isLoading ? 0.6 : 1.0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .task {
            await loadCurrentUser()
            await loadRepositories()
            if issues.isEmpty {
                await loadIssues()
            }
        }
    }

    private func loadCurrentUser() async {
        if let user = await GiteaAPIService.shared.getCurrentUser() {
            self.currentUsername = user.username
        }
    }

    private func loadRepositories() async {
        if let fetched = try? await GiteaAPIService.shared.fetchUserRepositories() {
            self.repositories = fetched
        }
    }

    private func loadIssues() async {
        isLoading = true
        errorMessage = nil
        do {
            if selectedRepoFullName != "ALL_REPOS" {
                let parts = selectedRepoFullName.split(separator: "/")
                if parts.count == 2 {
                    let owner = String(parts[0])
                    let repo = String(parts[1])
                    self.issues = try await GiteaAPIService.shared.fetchRepoIssues(owner: owner, repo: repo)
                } else {
                    self.issues = try await GiteaAPIService.shared.fetchAssignedIssues()
                }
            } else {
                self.issues = try await GiteaAPIService.shared.fetchAssignedIssues()
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Modern Polished Issue Single Card View
struct IssueCardView: View {
    let issue: GiteaIssue
    @ObservedObject var timerService = TimerService.shared

    var isCurrentActive: Bool {
        timerService.activeIssue?.id == issue.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Badges, Repo Name, Assignee & Actions
            HStack(spacing: 8) {
                // Type Badge: PR vs Issue
                HStack(spacing: 4) {
                    Image(systemName: issue.isPullRequest ? "arrow.triangle.pull" : "exclamationmark.circle")
                        .font(.caption2)
                    Text(issue.formattedKey)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(issue.isPullRequest ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2)))
                .foregroundColor(issue.isPullRequest ? .purple : .blue)
                .fixedSize()

                // Repository Name
                if let repo = issue.repository {
                    Text(repo.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Assignee Badge
                if let assignee = issue.assignee {
                    Text("@\(assignee.username)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                        .lineLimit(1)
                }

                Spacer()

                // Favorite Star
                Button {
                    timerService.toggleFavorite(issue)
                } label: {
                    Image(systemName: timerService.isFavorite(issue) ? "star.fill" : "star")
                        .font(.callout)
                        .foregroundColor(timerService.isFavorite(issue) ? .yellow : .gray.opacity(0.5))
                }
                .buttonStyle(.plain)

                // Select / Start Timer Button (or Dismiss if currently active)
                Button {
                    if isCurrentActive {
                        timerService.dismissActiveIssue()
                    } else {
                        timerService.start(issue: issue)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCurrentActive ? "checkmark.circle.fill" : "play.fill")
                        Text(isCurrentActive ? "Aktiv" : "Start")
                            .fontWeight(.bold)
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isCurrentActive ? Color.green : Color.blue)
                    )
                }
                .buttonStyle(.plain)
                .help(isCurrentActive ? "Klicken zum Abwählen" : "Timer für dieses Issue starten")
            }

            // Title
            Text(issue.title)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrentActive ? Color.green.opacity(0.1) : Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isCurrentActive ? Color.green.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
