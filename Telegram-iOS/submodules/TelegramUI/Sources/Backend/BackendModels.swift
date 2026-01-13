import Foundation

struct BackendUser: Codable, Equatable {
    let id: String
    let phone: String
    let displayName: String
    let avatarMediaId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case displayName = "display_name"
        case avatarMediaId = "avatar_media_id"
    }
}

struct BackendAuthResponse: Codable {
    let token: String
    let user: BackendUser
}

struct BackendChat: Codable, Equatable {
    let id: String
    let kind: String
    let title: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case createdAt = "created_at"
    }
}

struct BackendMessage: Codable, Equatable {
    let id: String
    let chatId: String
    let senderId: String
    let body: String?
    let mediaId: String?
    let createdAt: Date
    let editedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case senderId = "sender_id"
        case body
        case mediaId = "media_id"
        case createdAt = "created_at"
        case editedAt = "edited_at"
    }
}

struct BackendCallJoin: Codable {
    let callId: String
    let room: String
    let token: String
    let liveKitURL: String

    enum CodingKeys: String, CodingKey {
        case callId = "call_id"
        case room
        case token
        case liveKitURL = "livekit_url"
    }
}

struct BackendChatsResponse: Codable {
    let chats: [BackendChat]
}

struct BackendMessagesResponse: Codable {
    let messages: [BackendMessage]
}

struct BackendErrorResponse: Codable {
    let error: String
}
