import Foundation
import Testing
@testable import GiteaTimeTracker

struct UpdateCheckerTests {

    @Test func testVersionComparisonHigher() {
        #expect(UpdateChecker.compareVersions("1.0.5", "1.0.6") == .orderedAscending)
        #expect(UpdateChecker.compareVersions("1.0.5", "1.1.0") == .orderedAscending)
        #expect(UpdateChecker.compareVersions("1.0.5", "2.0.0") == .orderedAscending)
        #expect(UpdateChecker.compareVersions("1.0.18", "1.0.19") == .orderedAscending)
    }

    @Test func testVersionComparisonEqual() {
        #expect(UpdateChecker.compareVersions("1.0.5", "1.0.5") == .orderedSame)
        #expect(UpdateChecker.compareVersions("v1.0.5", "1.0.5") == .orderedSame)
        #expect(UpdateChecker.compareVersions("1.0.5", "V1.0.5") == .orderedSame)
        #expect(UpdateChecker.compareVersions("1.0.19", "v1.0.19") == .orderedSame)
    }

    @Test func testVersionComparisonLower() {
        #expect(UpdateChecker.compareVersions("1.0.6", "1.0.5") == .orderedDescending)
        #expect(UpdateChecker.compareVersions("2.0.0", "1.9.9") == .orderedDescending)
        #expect(UpdateChecker.compareVersions("1.0.19", "1.0.18") == .orderedDescending)
    }

    @Test func testGitHubReleaseDecoding() throws {
        let json = """
        {
          "tag_name": "v1.0.19",
          "name": "v1.0.19",
          "body": "## [1.0.19] - 2026-09-19\\n\\n### ✨ Added\\n- Open App Tray from Quick Switcher",
          "html_url": "https://github.com/Sneeex/gitea-time-tracker/releases/tag/v1.0.19",
          "published_at": "2026-09-19T21:26:10Z",
          "assets": [
            {
              "name": "GiteaTimeTracker.zip",
              "browser_download_url": "https://github.com/Sneeex/gitea-time-tracker/releases/download/v1.0.19/GiteaTimeTracker.zip"
            }
          ]
        }
        """

        let decoder = JSONDecoder()
        let release = try decoder.decode(GitHubRelease.self, from: json.data(using: .utf8)!)

        #expect(release.tagName == "v1.0.19")
        #expect(release.cleanVersion == "1.0.19")
        #expect(release.name == "v1.0.19")
        #expect(release.zipDownloadUrl == "https://github.com/Sneeex/gitea-time-tracker/releases/download/v1.0.19/GiteaTimeTracker.zip")
    }

    @Test @MainActor func testCheckForUpdatesLive() async {
        let checker = UpdateChecker.shared
        await checker.checkForUpdates(isManualCheck: true)

        #expect(checker.lastCheckError == nil)
        #expect(checker.latestRelease != nil)
        #expect(checker.latestRelease?.cleanVersion.isEmpty == false)
        #expect(checker.statusMessage != nil)
        #expect(checker.lastCheckDate != nil)
    }

    @Test @MainActor func testDismissPopup() {
        let checker = UpdateChecker.shared
        checker.showUpdatePopup = true
        checker.dismissPopup()
        #expect(checker.showUpdatePopup == false)
    }
}
