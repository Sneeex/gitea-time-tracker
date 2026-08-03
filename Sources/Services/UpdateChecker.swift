import Foundation
import AppKit
import Combine

public struct GitHubReleaseAsset: Codable, Equatable, Sendable {
    public let name: String
    public let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }

    public init(name: String, browserDownloadUrl: String) {
        self.name = name
        self.browserDownloadUrl = browserDownloadUrl
    }
}

public struct GitHubRelease: Codable, Equatable, Sendable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String
    public let publishedAt: String?
    public let assets: [GitHubReleaseAsset]?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    public init(tagName: String, name: String? = nil, body: String? = nil, htmlUrl: String, publishedAt: String? = nil, assets: [GitHubReleaseAsset]? = nil) {
        self.tagName = tagName
        self.name = name
        self.body = body
        self.htmlUrl = htmlUrl
        self.publishedAt = publishedAt
        self.assets = assets
    }

    public var cleanVersion: String {
        tagName.hasPrefix("v") || tagName.hasPrefix("V") ? String(tagName.dropFirst()) : tagName
    }

    public var zipDownloadUrl: String? {
        assets?.first(where: { $0.name.lowercased().hasSuffix(".zip") })?.browserDownloadUrl
    }
}

@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    @Published public var isChecking: Bool = false
    @Published public var isUpdateAvailable: Bool = false
    @Published public var showUpdatePopup: Bool = false
    @Published public var latestRelease: GitHubRelease? = nil
    @Published public var lastCheckError: String? = nil
    @Published public var statusMessage: String? = nil
    @Published public var lastCheckDate: Date? = nil

    private static let autoCheckKey = "autoCheckForUpdates"

    public var isAutoCheckEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.autoCheckKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.autoCheckKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.autoCheckKey)
            objectWillChange.send()
        }
    }

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.8"
    }

    private let repositoryOwner = "Sneeex"
    private let repositoryName = "gitea-time-tracker"

    private init() {}

    public func checkForUpdatesOnLaunch() {
        guard isAutoCheckEnabled else { return }
        Task {
            await checkForUpdates(isManualCheck: false)
        }
    }

    public func checkForUpdates(isManualCheck: Bool = false) async {
        isChecking = true
        lastCheckError = nil
        statusMessage = nil

        let urlString = "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest"
        guard let url = URL(string: urlString) else {
            isChecking = false
            lastCheckError = "Ungültige Update-URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GiteaTimeTracker-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "UpdateChecker", code: 0, userInfo: [NSLocalizedDescriptionKey: "Ungültige Serverantwort."])
            }

            if httpResponse.statusCode == 404 {
                isChecking = false
                if isManualCheck {
                    statusMessage = "Keine Veröffentlichungen auf GitHub gefunden."
                }
                lastCheckDate = Date()
                return
            }

            guard httpResponse.statusCode == 200 else {
                throw NSError(domain: "UpdateChecker", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP-Fehler \(httpResponse.statusCode)"])
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            self.latestRelease = release
            self.lastCheckDate = Date()

            let comparison = Self.compareVersions(currentVersion, release.cleanVersion)
            if comparison == .orderedAscending {
                // New update available!
                self.isUpdateAvailable = true
                self.showUpdatePopup = true
                self.statusMessage = "Neue Version \(release.cleanVersion) verfügbar!"
                NSApp.activate(ignoringOtherApps: true)
            } else {
                self.isUpdateAvailable = false
                self.showUpdatePopup = false
                if isManualCheck {
                    self.statusMessage = "Du verwendest bereits die neueste Version (v\(currentVersion))."
                }
            }
        } catch {
            self.lastCheckError = "Fehler beim Prüfen auf Updates: \(error.localizedDescription)"
        }

        self.isChecking = false
    }

    public func dismissPopup() {
        self.showUpdatePopup = false
    }

    /// Compares two semver strings like "1.0.5" vs "1.0.6".
    /// Returns:
    /// - `.orderedAscending` if `version1` < `version2` (i.e. update available)
    /// - `.orderedSame` if equal
    /// - `.orderedDescending` if `version1` > `version2`
    nonisolated public static func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let clean1 = version1.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).trimmingCharacters(in: .whitespacesAndNewlines)
        let clean2 = version2.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).trimmingCharacters(in: .whitespacesAndNewlines)

        let parts1 = clean1.split(separator: ".").compactMap { Int($0) }
        let parts2 = clean2.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(parts1.count, parts2.count)

        for i in 0..<maxCount {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0

            if p1 < p2 {
                return .orderedAscending
            } else if p1 > p2 {
                return .orderedDescending
            }
        }

        return .orderedSame
    }
}
