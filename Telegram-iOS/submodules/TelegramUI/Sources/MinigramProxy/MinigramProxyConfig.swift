import Foundation
import Postbox
import TelegramCore
import MtProtoKit

enum MinigramProxyMode {
    case mtproto(secretHex: String)
    case socks5(username: String?, password: String?)
}

enum MinigramProxyConfig {
    private static func env(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }

    private static let localPlist: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "MinigramLocal", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = object as? [String: Any] else {
            return nil
        }
        return dict
    }()

    private static func rawValue(_ key: String) -> Any? {
        if let value = env(key) {
            return value
        }
        if let value = localPlist?[key] {
            return value
        }
        return Bundle.main.object(forInfoDictionaryKey: key)
    }

    private static func stringValue(_ key: String) -> String? {
        guard let value = rawValue(key) else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("$(") && trimmed.hasSuffix(")") {
                return nil
            }
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func boolValue(_ key: String, defaultValue: Bool) -> Bool {
        guard let value = rawValue(key) else { return defaultValue }
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "y":
                return true
            case "0", "false", "no", "n":
                return false
            default:
                break
            }
        }
        return defaultValue
    }

    private static func int32Value(_ key: String, defaultValue: Int32) -> Int32 {
        guard let value = rawValue(key) else { return defaultValue }
        if let number = value as? NSNumber {
            return number.int32Value
        }
        if let string = value as? String, let parsed = Int32(string) {
            return parsed
        }
        return defaultValue
    }

    static let enabled = boolValue("MINIGRAM_PROXY_ENABLED", defaultValue: false)
    static let overrideExisting = boolValue("MINIGRAM_PROXY_OVERRIDE", defaultValue: true)
    static let useForCalls = boolValue("MINIGRAM_PROXY_USE_FOR_CALLS", defaultValue: true)

    static let host = stringValue("MINIGRAM_PROXY_HOST") ?? ""
    static let port: Int32 = int32Value("MINIGRAM_PROXY_PORT", defaultValue: 0)

    static let mode: MinigramProxyMode = {
        let type = stringValue("MINIGRAM_PROXY_TYPE")?.lowercased() ?? "socks5"
        switch type {
        case "mtp", "mtproto":
            return .mtproto(secretHex: stringValue("MINIGRAM_PROXY_SECRET") ?? "")
        default:
            return .socks5(
                username: stringValue("MINIGRAM_PROXY_USER"),
                password: stringValue("MINIGRAM_PROXY_PASS")
            )
        }
    }()
}

func applyMinigramProxySettingsIfNeeded(accountManager: AccountManager<TelegramAccountManagerTypes>) {
    guard MinigramProxyConfig.enabled else {
        return
    }
    guard !MinigramProxyConfig.host.isEmpty, MinigramProxyConfig.port > 0 else {
        return
    }

    let connection: ProxyServerConnection
    switch MinigramProxyConfig.mode {
    case let .socks5(username, password):
        connection = .socks5(username: username, password: password)
    case let .mtproto(secretHex):
        guard let parsed = MTProxySecret.parse(secretHex) else {
            return
        }
        connection = .mtp(secret: parsed.serialize())
    }

    let server = ProxyServerSettings(
        host: MinigramProxyConfig.host,
        port: MinigramProxyConfig.port,
        connection: connection
    )

    let _ = updateProxySettingsInteractively(accountManager: accountManager) { current in
        if !MinigramProxyConfig.overrideExisting, !current.servers.isEmpty {
            return current
        }

        var updated = current
        if !updated.servers.contains(server) {
            updated.servers.append(server)
        }
        updated.activeServer = server
        updated.enabled = true
        updated.useForCalls = MinigramProxyConfig.useForCalls
        return updated
    }.start()
}
