import Foundation

enum BackendAPIError: Error {
    case invalidResponse
    case httpStatus(Int, String?)
}

final class BackendAPI {
    static let shared = BackendAPI()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let tokenStore: BackendSession

    private init() {
        self.session = URLSession(configuration: .default)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.tokenStore = BackendSession.shared
    }

    func requestAuthCode(phone: String) async throws {
        let body = ["phone": phone]
        let request = try makeRequest(path: "/v1/auth/request", method: "POST", body: body, authorized: false)
        _ = try await perform(request, as: BackendSentResponse.self)
    }

    func verifyCode(phone: String, code: String, name: String) async throws -> BackendAuthResponse {
        let body = ["phone": phone, "code": code, "name": name]
        let request = try makeRequest(path: "/v1/auth/verify", method: "POST", body: body, authorized: false)
        return try await perform(request, as: BackendAuthResponse.self)
    }

    func authorizeBot(code: String, name: String) async throws -> BackendAuthResponse {
        let body = ["code": code, "name": name]
        let request = try makeRequest(path: "/v1/auth/bot", method: "POST", body: body, authorized: false)
        return try await perform(request, as: BackendAuthResponse.self)
    }

    func fetchMe() async throws -> BackendUser {
        let request = try makeRequest(path: "/v1/me", method: "GET", body: nil, authorized: true)
        return try await perform(request, as: BackendUser.self)
    }

    func listChats() async throws -> [BackendChat] {
        let request = try makeRequest(path: "/v1/chats", method: "GET", body: nil, authorized: true)
        let response = try await perform(request, as: BackendChatsResponse.self)
        return response.chats
    }

    func createDirectChat(userId: String) async throws -> BackendChat {
        let body = ["kind": "direct", "user_id": userId]
        let request = try makeRequest(path: "/v1/chats", method: "POST", body: body, authorized: true)
        return try await perform(request, as: BackendChat.self)
    }

    func listMessages(chatId: String, limit: Int = 50) async throws -> [BackendMessage] {
        var components = URLComponents(url: BackendConfig.baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/v1/chats/\(chatId)/messages"
        components?.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components?.url else {
            throw BackendAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthorizationIfNeeded(&request)
        let response = try await perform(request, as: BackendMessagesResponse.self)
        return response.messages
    }

    func sendMessage(chatId: String, body: String) async throws -> BackendMessage {
        let payload = ["body": body]
        let request = try makeRequest(path: "/v1/chats/\(chatId)/messages", method: "POST", body: payload, authorized: true)
        return try await perform(request, as: BackendMessage.self)
    }

    func createCall(chatId: String? = nil) async throws -> BackendCallJoin {
        let payload = BackendCreateCallPayload(chatId: chatId?.isEmpty == true ? nil : chatId)
        let request = try makeRequest(path: "/v1/calls", method: "POST", body: payload, authorized: true)
        return try await perform(request, as: BackendCallJoin.self)
    }

    func joinCall(callId: String) async throws -> BackendCallJoin {
        let payload = ["call_id": callId]
        let request = try makeRequest(path: "/v1/calls/join", method: "POST", body: payload, authorized: true)
        return try await perform(request, as: BackendCallJoin.self)
    }

    private func makeRequest(path: String, method: String, body: [String: String]?, authorized: Bool) throws -> URLRequest {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = BackendConfig.baseURL.appendingPathComponent(cleanPath)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized {
            addAuthorizationIfNeeded(&request)
        }
        if let body {
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    private func makeRequest<T: Encodable>(path: String, method: String, body: T, authorized: Bool) throws -> URLRequest {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = BackendConfig.baseURL.appendingPathComponent(cleanPath)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized {
            addAuthorizationIfNeeded(&request)
        }
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func addAuthorizationIfNeeded(_ request: inout URLRequest) {
        if let token = tokenStore.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }
        if http.statusCode >= 400 {
            let errorResponse = try? decoder.decode(BackendErrorResponse.self, from: data)
            throw BackendAPIError.httpStatus(http.statusCode, errorResponse?.error)
        }
        return try decoder.decode(T.self, from: data)
    }
}

private struct BackendSentResponse: Codable {
    let sent: Bool
}

private struct BackendCreateCallPayload: Codable {
    let chatId: String?

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
    }
}
