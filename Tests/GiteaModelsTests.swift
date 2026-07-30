import Testing
import Foundation
@testable import GiteaTimeTracker

struct GiteaModelsTests {

    @Test func testDecodeGiteaIssueWithDictOwner() throws {
        let json = """
        {
            "id": 101,
            "number": 42,
            "title": "Fix login bug in menu bar",
            "state": "open",
            "repository": {
                "id": 12,
                "name": "gitea-app",
                "full_name": "developer/gitea-app",
                "owner": {
                    "id": 1,
                    "username": "developer"
                }
            }
        }
        """.data(using: .utf8)!

        let issue = try JSONDecoder().decode(GiteaIssue.self, from: json)
        #expect(issue.id == 101)
        #expect(issue.number == 42)
        #expect(issue.title == "Fix login bug in menu bar")
        #expect(issue.formattedKey == "#42")
        #expect(issue.repoOwnerName == "developer")
    }

    @Test func testDecodeGiteaIssueWithStringOwner() throws {
        let json = """
        {
            "id": 202,
            "number": 15,
            "title": "Build Tallee App feature",
            "state": "open",
            "repository": {
                "id": 99,
                "name": "tallee-app",
                "full_name": "liquid-development/tallee-app",
                "owner": "liquid-development"
            }
        }
        """.data(using: .utf8)!

        let issue = try JSONDecoder().decode(GiteaIssue.self, from: json)
        #expect(issue.id == 202)
        #expect(issue.number == 15)
        #expect(issue.title == "Build Tallee App feature")
        #expect(issue.formattedKey == "#15")
        #expect(issue.repoOwnerName == "liquid-development")
    }

    @Test func testTimeLogEntryCodable() throws {
        let entry = TimeLogEntry(
            repoOwner: "dev",
            repoName: "my-project",
            issueIndex: 5,
            issueTitle: "Refactor API",
            seconds: 3600,
            isSynced: false
        )

        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TimeLogEntry.self, from: encoded)

        #expect(decoded.repoOwner == "dev")
        #expect(decoded.repoName == "my-project")
        #expect(decoded.issueIndex == 5)
        #expect(decoded.seconds == 3600)
        #expect(decoded.isSynced == false)
    }
}
