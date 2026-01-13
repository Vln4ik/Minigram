import Foundation

final class BackendSession {
    static let shared = BackendSession()

    private let tokenKey = "mini_backend_token"
    private let userKey = "mini_backend_user"

    private let defaults = UserDefaults.standard

    private init() {}

    var token: String? {
        get { defaults.string(forKey: tokenKey) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: tokenKey)
            } else {
                defaults.removeObject(forKey: tokenKey)
            }
        }
    }

    var user: BackendUser? {
        get {
            guard let data = defaults.data(forKey: userKey) else {
                return nil
            }
            return try? JSONDecoder().decode(BackendUser.self, from: data)
        }
        set {
            if let value = newValue, let data = try? JSONEncoder().encode(value) {
                defaults.set(data, forKey: userKey)
            } else {
                defaults.removeObject(forKey: userKey)
            }
        }
    }

    var isAuthorized: Bool {
        return token != nil && user != nil
    }

    func update(from auth: BackendAuthResponse) {
        token = auth.token
        user = auth.user
    }

    func clear() {
        token = nil
        user = nil
    }
}
