import Foundation
import Testing
@testable import GiteaTimeTracker

struct UpdateCheckerTests {

    @Test func testVersionComparisonHigher() {
        #expect(UpdateChecker.compareVersions("1.0.5", "1.0.6") == .orderedAscending)
        #expect(UpdateChecker.compareVersions("1.0.5", "1.1.0") == .orderedAscending)
        #expect(UpdateChecker.compareVersions("1.0.5", "2.0.0") == .orderedAscending)
    }

    @Test func testVersionComparisonEqual() {
        #expect(UpdateChecker.compareVersions("1.0.5", "1.0.5") == .orderedSame)
        #expect(UpdateChecker.compareVersions("v1.0.5", "1.0.5") == .orderedSame)
        #expect(UpdateChecker.compareVersions("1.0.5", "V1.0.5") == .orderedSame)
    }

    @Test func testVersionComparisonLower() {
        #expect(UpdateChecker.compareVersions("1.0.6", "1.0.5") == .orderedDescending)
        #expect(UpdateChecker.compareVersions("2.0.0", "1.9.9") == .orderedDescending)
    }

    @Test func testGitHubReleaseDecoding() throws {
        let json = """
        {
          "tag_name": "v1.0.6",
          "name": "Release v1.0.6",
          "body": "Fixed bugs and added update checker",
          "html_url": "https://github.com/Sneeex/gitea-time-tracker/releases/tag/v1.0.6",
          "published_at": "2026-07-31T20:00:00Z",
          "assets": [
            {
              "name": "GiteaTimeTracker.zip",
              "browser_download_url": "https://github.com/Sneeex/gitea-time-tracker/releases/download/v1.0.6/GiteaTimeTracker.zip"
            }
          ]
        }
        """

        let decoder = JSONDecoder()
        let release = try decoder.decode(GitHubRelease.self, from: json.data(using: .utf8)!)

        #expect(release.tagName == "v1.0.6")
        #expect(release.cleanVersion == "1.0.6")
        #expect(release.name == "Release v1.0.6")
        #expect(release.zipDownloadUrl == "https://github.com/Sneeex/gitea-time-tracker/releases/download/v1.0.6/GiteaTimeTracker.zip")
    }
}
