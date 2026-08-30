import Foundation
import SwiftUI

@MainActor
public class IssueStore: ObservableObject {
    public static let shared = IssueStore()
    
    @Published public var issues: [GiteaIssue] = []
    @Published public var repositories: [GiteaRepository] = []
    @Published public var currentUsername: String?
    
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    @AppStorage("gitea_selected_repo_fullname") private var selectedRepoFullName: String = "ALL_REPOS"
    
    private init() {}
    
    public func loadInitialData() async {
        await loadCurrentUser()
        await loadRepositories()
        if issues.isEmpty {
            await loadIssues()
        }
    }
    
    public func loadCurrentUser() async {
        if let user = await GiteaAPIService.shared.getCurrentUser() {
            self.currentUsername = user.username
        }
    }
    
    public func loadRepositories() async {
        if let fetched = try? await GiteaAPIService.shared.fetchUserRepositories() {
            self.repositories = fetched
        }
    }
    
    public func loadIssues() async {
        isLoading = true
        errorMessage = nil
        do {
            var fetched: [GiteaIssue]? = nil
            if selectedRepoFullName != "ALL_REPOS" {
                let parts = selectedRepoFullName.split(separator: "/")
                if parts.count == 2 {
                    let owner = String(parts[0])
                    let repo = String(parts[1])
                    fetched = try await GiteaAPIService.shared.fetchRepoIssues(owner: owner, repo: repo)
                } else {
                    fetched = try await GiteaAPIService.shared.fetchAssignedIssues()
                }
            } else {
                fetched = try await GiteaAPIService.shared.fetchAssignedIssues()
            }
            
            if let fetchedIssues = fetched {
                var allIssues = fetchedIssues
                // Ensure recent issues from TimerService are always included at the top
                for recent in TimerService.shared.recentIssues.reversed() {
                    if !allIssues.contains(where: { $0.id == recent.id }) {
                        allIssues.insert(recent, at: 0)
                    }
                }
                
                let recentIDs = TimerService.shared.recentIssues.map { $0.id }
                self.issues = allIssues.sorted { a, b in
                    let indexA = recentIDs.firstIndex(of: a.id)
                    let indexB = recentIDs.firstIndex(of: b.id)
                    
                    if let aIdx = indexA, let bIdx = indexB {
                        return aIdx < bIdx
                    } else if indexA != nil {
                        return true
                    } else if indexB != nil {
                        return false
                    } else {
                        return a.id > b.id
                    }
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
            print("Failed to fetch issues: \(error)")
        }
        isLoading = false
    }
}
