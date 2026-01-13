import Foundation

enum BackendConfig {
    private static let baseURLKey = "mini_backend_base_url"
    private static let enabledKey = "mini_backend_enabled"

    static let defaultBaseURLString = "http://62.60.148.13:8080"

    static var baseURL: URL {
        if let env = ProcessInfo.processInfo.environment["MINI_BACKEND_URL"], let url = URL(string: env) {
            return url
        }
        if let stored = UserDefaults.standard.string(forKey: baseURLKey), let url = URL(string: stored) {
            return url
        }
        return URL(string: defaultBaseURLString)!
    }

    static var isEnabled: Bool {
        if let env = ProcessInfo.processInfo.environment["MINI_BACKEND_MODE"] {
            return env != "0"
        }
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        return false
    }

    static func updateBaseURL(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: baseURLKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }
}
