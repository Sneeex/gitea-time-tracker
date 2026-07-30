import Foundation

// MARK: - Gitea User / Owner
public struct GiteaUser: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let username: String
    public let fullName: String?
    public let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }

    public init(id: Int, username: String, fullName: String? = nil, avatarUrl: String? = nil) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.avatarUrl = avatarUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(Int.self, forKey: .id)) ?? 0
        self.username = (try? container.decode(String.self, forKey: .username)) ?? "Unknown"
        self.fullName = try? container.decode(String.self, forKey: .fullName)
        self.avatarUrl = try? container.decode(String.self, forKey: .avatarUrl)
    }
}

// MARK: - Gitea Repository
public struct GiteaRepository: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let fullName: String?
    public let owner: GiteaUser?
    public let htmlUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case owner
        case htmlUrl = "html_url"
    }

    public init(id: Int, name: String, fullName: String? = nil, owner: GiteaUser? = nil, htmlUrl: String? = nil) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.owner = owner
        self.htmlUrl = htmlUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(Int.self, forKey: .id)) ?? 0
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        self.fullName = try? container.decode(String.self, forKey: .fullName)
        self.htmlUrl = try? container.decode(String.self, forKey: .htmlUrl)

        if let userObj = try? container.decode(GiteaUser.self, forKey: .owner) {
            self.owner = userObj
        } else if let strName = try? container.decode(String.self, forKey: .owner) {
            self.owner = GiteaUser(id: 0, username: strName)
        } else {
            self.owner = nil
        }
    }

    public var ownerName: String {
        if let owner = owner {
            return owner.username
        }
        if let fn = fullName, fn.contains("/") {
            return String(fn.split(separator: "/")[0])
        }
        return "Unknown"
    }
}

// MARK: - Gitea Pull Request Metadata
public struct GiteaPullRequestMeta: Codable, Hashable, Sendable {
    public let merged: Bool?

    public init(merged: Bool? = nil) {
        self.merged = merged
    }
}

// MARK: - Gitea Issue
public struct GiteaIssue: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let number: Int
    public let title: String
    public let body: String?
    public let state: String // "open", "closed"
    public var repository: GiteaRepository?
    public let assignee: GiteaUser?
    public let pullRequest: GiteaPullRequestMeta?
    public let htmlUrl: String?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case body
        case state
        case repository
        case assignee
        case pullRequest = "pull_request"
        case htmlUrl = "html_url"
        case updatedAt = "updated_at"
    }

    public init(
        id: Int,
        number: Int,
        title: String,
        body: String? = nil,
        state: String = "open",
        repository: GiteaRepository? = nil,
        assignee: GiteaUser? = nil,
        pullRequest: GiteaPullRequestMeta? = nil,
        htmlUrl: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.state = state
        self.repository = repository
        self.assignee = assignee
        self.pullRequest = pullRequest
        self.htmlUrl = htmlUrl
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.number = try container.decode(Int.self, forKey: .number)
        self.title = try container.decode(String.self, forKey: .title)
        self.body = try? container.decode(String.self, forKey: .body)
        self.state = (try? container.decode(String.self, forKey: .state)) ?? "open"
        self.repository = try? container.decode(GiteaRepository.self, forKey: .repository)
        self.pullRequest = try? container.decode(GiteaPullRequestMeta.self, forKey: .pullRequest)
        self.htmlUrl = try? container.decode(String.self, forKey: .htmlUrl)
        self.updatedAt = try? container.decode(Date.self, forKey: .updatedAt)

        if let userObj = try? container.decode(GiteaUser.self, forKey: .assignee) {
            self.assignee = userObj
        } else if let strName = try? container.decode(String.self, forKey: .assignee) {
            self.assignee = GiteaUser(id: 0, username: strName)
        } else {
            self.assignee = nil
        }
    }

    public var isPullRequest: Bool {
        pullRequest != nil
    }

    public var repoOwnerName: String {
        if let repo = repository {
            return repo.ownerName
        }
        return "Unknown"
    }

    public var repoName: String {
        repository?.name ?? "Unknown"
    }

    public var formattedKey: String {
        "#\(number)"
    }
}

// MARK: - Gitea Tracked Time Response
public struct GiteaTrackedTime: Codable, Identifiable, Sendable {
    public let id: Int
    public let time: Int // seconds
    public let createdAt: Date?
    public let user: GiteaUser?

    enum CodingKeys: String, CodingKey {
        case id
        case time
        case createdAt = "created"
        case user
    }
}

// MARK: - Local Offline Time Log Entry
public struct TimeLogEntry: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let repoOwner: String
    public let repoName: String
    public let issueIndex: Int
    public let issueTitle: String
    public let seconds: Int
    public let createdAt: Date
    public var isSynced: Bool

    public init(
        id: UUID = UUID(),
        repoOwner: String,
        repoName: String,
        issueIndex: Int,
        issueTitle: String,
        seconds: Int,
        createdAt: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.repoOwner = repoOwner
        self.repoName = repoName
        self.issueIndex = issueIndex
        self.issueTitle = issueTitle
        self.seconds = seconds
        self.createdAt = createdAt
        self.isSynced = isSynced
    }
}
