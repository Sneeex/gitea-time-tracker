import Foundation

public enum GiteaAPIError: LocalizedError, Sendable {
    case invalidURL
    case missingToken
    case unauthorized
    case serverError(statusCode: Int, message: String?)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige Gitea Server-URL."
        case .missingToken:
            return "Kein Personal Access Token (PAT) konfiguriert."
        case .unauthorized:
            return "Ungültiger Token oder fehlende Berechtigungen (401/403)."
        case .serverError(let statusCode, let message):
            if let msg = message, !msg.isEmpty {
                return "Gitea Server Fehler (HTTP \(statusCode)): \(msg)"
            }
            return "Gitea Server Fehler (HTTP \(statusCode))."
        case .networkError(let msg):
            return "Netzwerkfehler: \(msg)"
        }
    }
}

public actor GiteaAPIService {
    public static let shared = GiteaAPIService()
    private let session: URLSession
    private var cachedUser: GiteaUser?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: config)
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ decoder in
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: str) {
                    return date
                }
                let stdFormatter = ISO8601DateFormatter()
                if let date = stdFormatter.date(from: str) {
                    return date
                }
            } else if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            return Date()
        })
        return decoder
    }

    private func makeRequest(endpoint: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        let rawURL = KeychainService.shared.getServerURL().trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let baseString = rawURL.starts(with: "http://") || rawURL.starts(with: "https://") ? rawURL : "https://\(rawURL)"
        
        let cleanedEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let fullURLString = "\(baseString)/api/v1/\(cleanedEndpoint)"
        
        guard let fullURL = URL(string: fullURLString) else {
            throw GiteaAPIError.invalidURL
        }
        
        guard let token = KeychainService.shared.getToken(), !token.isEmpty else {
            throw GiteaAPIError.missingToken
        }

        var request = URLRequest(url: fullURL)
        request.httpMethod = method
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        return request
    }

    // MARK: - API Calls

    /// Validates token & server connection and caches current user
    public func testConnection() async throws -> GiteaUser {
        let request = try makeRequest(endpoint: "user")
        let (data, response) = try await session.data(for: request)

        guard let httpStatus = response as? HTTPURLResponse else {
            throw GiteaAPIError.networkError("Ungültige Server-Antwort.")
        }

        if httpStatus.statusCode == 401 || httpStatus.statusCode == 403 {
            throw GiteaAPIError.unauthorized
        }

        guard httpStatus.statusCode == 200 else {
            let msg = parseErrorMessage(from: data)
            throw GiteaAPIError.serverError(statusCode: httpStatus.statusCode, message: msg)
        }

        let user = try makeDecoder().decode(GiteaUser.self, from: data)
        self.cachedUser = user
        return user
    }

    public func getCurrentUser() async -> GiteaUser? {
        if let user = cachedUser {
            return user
        }
        return try? await testConnection()
    }

    /// Fetches all accessible repositories including user and organization repos
    public func fetchUserRepositories() async throws -> [GiteaRepository] {
        var allRepos: [GiteaRepository] = []

        // 1. Personal Repos: /api/v1/user/repos
        if let userRepos = try? await fetchReposFromEndpoint("user/repos?limit=100") {
            allRepos.append(contentsOf: userRepos)
        }

        // 2. User Orgs: /api/v1/user/orgs -> /api/v1/orgs/{org}/repos
        if let orgs = try? await fetchOrgsFromEndpoint("user/orgs") {
            for org in orgs {
                let endpoint = "orgs/\(org.username)/repos?limit=100"
                if let orgRepos = try? await fetchReposFromEndpoint(endpoint) {
                    allRepos.append(contentsOf: orgRepos)
                }
            }
        }

        // Deduplicate by repo ID
        var map: [Int: GiteaRepository] = [:]
        for repo in allRepos {
            map[repo.id] = repo
        }
        return Array(map.values).sorted { ($0.fullName ?? $0.name) < ($1.fullName ?? $1.name) }
    }

    /// Fetches open issues for a specific repository (e.g. owner: "liquid-development", repo: "tallee-app")
    public func fetchRepoIssues(owner: String, repo: String) async throws -> [GiteaIssue] {
        let endpoint = "repos/\(owner)/\(repo)/issues?state=open&limit=100"
        let request = try makeRequest(endpoint: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpStatus = response as? HTTPURLResponse else {
            throw GiteaAPIError.networkError("Keine Server-Antwort.")
        }

        if httpStatus.statusCode != 200 {
            let serverMsg = parseErrorMessage(from: data)
            throw GiteaAPIError.serverError(statusCode: httpStatus.statusCode, message: serverMsg)
        }

        var decodedIssues = try makeDecoder().decode([GiteaIssue].self, from: data)

        // Ensure repo information is set on each issue
        let fallbackRepo = GiteaRepository(
            id: 0,
            name: repo,
            fullName: "\(owner)/\(repo)",
            owner: GiteaUser(id: 0, username: owner)
        )

        for i in 0..<decodedIssues.count {
            if decodedIssues[i].repository == nil {
                decodedIssues[i].repository = fallbackRepo
            }
        }

        return decodedIssues
    }

    public func isFilterOnlyMyReposEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: "gitea_filter_only_my_repos") != nil {
            return UserDefaults.standard.bool(forKey: "gitea_filter_only_my_repos")
        }
        return true
    }

    public func setFilterOnlyMyReposEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "gitea_filter_only_my_repos")
    }

    /// Fetches all accessible issues using multi-strategy fallback
    public func fetchAssignedIssues() async throws -> [GiteaIssue] {
        var fetchedIssues: [GiteaIssue] = []

        // Strategy 1: GET /api/v1/issues?state=open&limit=100
        if let globalIssues = try? await fetchIssuesFromEndpoint("issues?state=open&limit=100") {
            fetchedIssues.append(contentsOf: globalIssues)
        }

        // Strategy 2: GET /api/v1/user/issues?state=open&limit=100
        if let userIssues = try? await fetchIssuesFromEndpoint("user/issues?state=open&limit=100") {
            fetchedIssues.append(contentsOf: userIssues)
        }

        // Strategy 3: GET /api/v1/repos/issues/search?state=open&limit=100
        if let searchIssues = try? await fetchIssuesFromEndpoint("repos/issues/search?state=open&limit=100") {
            fetchedIssues.append(contentsOf: searchIssues)
        }

        // Deduplicate by issue ID
        var uniqueMap: [Int: GiteaIssue] = [:]
        for issue in fetchedIssues {
            uniqueMap[issue.id] = issue
        }

        var allList = Array(uniqueMap.values).sorted { $0.id > $1.id }

        // Filter out non-member public repos if setting enabled
        if isFilterOnlyMyReposEnabled() {
            if let myRepos = try? await fetchUserRepositories() {
                let myRepoNames = Set(myRepos.compactMap { $0.fullName?.lowercased() ?? $0.name.lowercased() })
                let myRepoIDs = Set(myRepos.map { $0.id })

                allList = allList.filter { issue in
                    guard let repo = issue.repository else { return true }
                    let fullName = (repo.fullName ?? "\(repo.ownerName)/\(repo.name)").lowercased()
                    return myRepoIDs.contains(repo.id) || myRepoNames.contains(fullName)
                }
            }
        }

        return allList
    }

    private func fetchIssuesFromEndpoint(_ endpoint: String) async throws -> [GiteaIssue] {
        let request = try makeRequest(endpoint: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode == 200 else {
            return []
        }

        do {
            return try makeDecoder().decode([GiteaIssue].self, from: data)
        } catch {
            print("Failed to decode issues from \(endpoint): \(error)")
            return []
        }
    }

    private func fetchReposFromEndpoint(_ endpoint: String) async throws -> [GiteaRepository] {
        let request = try makeRequest(endpoint: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode == 200 else {
            return []
        }

        return try makeDecoder().decode([GiteaRepository].self, from: data)
    }

    private func fetchOrgsFromEndpoint(_ endpoint: String) async throws -> [GiteaUser] {
        let request = try makeRequest(endpoint: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode == 200 else {
            return []
        }

        return try makeDecoder().decode([GiteaUser].self, from: data)
    }

    private func parseErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg = json["message"] as? String {
            return msg
        }
        if let str = String(data: data, encoding: .utf8), !str.isEmpty {
            return str
        }
        return "Keine weiteren Details vom Server."
    }

    public func logTime(owner: String, repo: String, index: Int, seconds: Int) async throws {
        guard seconds > 0 else { return }

        let payload: [String: Any] = [
            "time": Int64(seconds)
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        let endpoint = "repos/\(owner)/\(repo)/issues/\(index)/times"
        let request = try makeRequest(endpoint: endpoint, method: "POST", body: jsonData)

        let (data, response) = try await session.data(for: request)

        guard let httpStatus = response as? HTTPURLResponse else {
            throw GiteaAPIError.networkError("Verbindung unterbrochen.")
        }

        if httpStatus.statusCode == 401 || httpStatus.statusCode == 403 {
            throw GiteaAPIError.unauthorized
        }

        guard (200...299).contains(httpStatus.statusCode) else {
            let msg = parseErrorMessage(from: data)
            throw GiteaAPIError.serverError(statusCode: httpStatus.statusCode, message: msg)
        }
    }
}
