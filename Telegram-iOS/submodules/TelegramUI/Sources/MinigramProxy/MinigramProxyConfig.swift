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

    private static func envBool(_ key: String, defaultValue: Bool) -> Bool {
        guard let value = env(key)?.lowercased() else { return defaultValue }
        return value == "1" || value == "true" || value == "yes"
    }

    private static func envInt32(_ key: String, defaultValue: Int32) -> Int32 {
        guard let value = env(key), let parsed = Int32(value) else { return defaultValue }
        return parsed
    }

    static let enabled = envBool("MINIGRAM_PROXY_ENABLED", defaultValue: false)
    static let overrideExisting = envBool("MINIGRAM_PROXY_OVERRIDE", defaultValue: true)
    static let useForCalls = envBool("MINIGRAM_PROXY_USE_FOR_CALLS", defaultValue: true)

    static let host = env("MINIGRAM_PROXY_HOST") ?? ""
    static let port: Int32 = envInt32("MINIGRAM_PROXY_PORT", defaultValue: 0)

    static let mode: MinigramProxyMode = {
        let type = env("MINIGRAM_PROXY_TYPE")?.lowercased() ?? "socks5"
        switch type {
        case "mtp", "mtproto":
            return .mtproto(secretHex: env("MINIGRAM_PROXY_SECRET") ?? "")
        default:
            return .socks5(
                username: env("MINIGRAM_PROXY_USER"),
                password: env("MINIGRAM_PROXY_PASS")
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
