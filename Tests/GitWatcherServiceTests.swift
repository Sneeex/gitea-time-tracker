import Testing
import Foundation
@testable import GiteaTimeTracker

struct GitWatcherServiceTests {

    @Test @MainActor func testExtractIssueNumberFromBranchNames() {
        let service = GitWatcherService.shared

        #expect(service.extractIssueNumber(from: "feature/#42-auth-bug") == 42)
        #expect(service.extractIssueNumber(from: "feature/42-auth-bug") == 42)
        #expect(service.extractIssueNumber(from: "fix/issue-105-crash") == 105)
        #expect(service.extractIssueNumber(from: "bug/789") == 789)
        #expect(service.extractIssueNumber(from: "123-quick-fix") == 123)
        #expect(service.extractIssueNumber(from: "main") == nil)
        #expect(service.extractIssueNumber(from: "release/v1.0.0") == nil)
    }
}
