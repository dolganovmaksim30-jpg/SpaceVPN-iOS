import Foundation

final class ShareLinkParser {

    /// Загружает подписку по URL. Если контент в base64 — декодирует. Возвращает список профилей.
    static func fetchSubscription(urlString: String,
                                  completion: @escaping (Result<[VPNProfile], Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "bad url", code: 0))); return
        }

        var request = URLRequest(url: url)
        request.setValue("SpaceVPN/1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error)); return
            }
            guard let data = data,
                  let raw = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "no data", code: 0))); return
            }
            let text = decodeBase64IfNeeded(raw)
            let profiles = parseLines(text)
            completion(.success(profiles))
        }.resume()
    }

    /// Если текст не содержит `://` — значит скорее всего это base64. Пытаемся декодировать.
    static func decodeBase64IfNeeded(_ text: String) -> String {
        if text.contains("://") { return text }
        // Чистим от переводов строк и пробелов
        var cleaned = text
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Иногда прилетает URL-safe base64 — меняем на обычный
        cleaned = cleaned.replacingOccurrences(of: "-", with: "+")
                         .replacingOccurrences(of: "_", with: "/")
        // Добиваем паддинг '=' до кратности 4
        let rem = cleaned.count % 4
        if rem > 0 { cleaned += String(repeating: "=", count: 4 - rem) }

        if let data = Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters),
           let decoded = String(data: data, encoding: .utf8) {
            return decoded
        }
        return text
    }

    /// Разбирает строки-ссылки в массив профилей.
    static func parseLines(_ text: String) -> [VPNProfile] {
        var result: [VPNProfile] = []
        for line in text.components(separatedBy: .newlines) {
            let s = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !s.isEmpty else { continue }

            if s.lowercased().hasPrefix("vless://"),
               let p = parseVLESS(s) { result.append(p) }
            else if s.lowercased().hasPrefix("hysteria2://") || s.lowercased().hasPrefix("hy2://"),
               let p = parseHysteria2(s) { result.append(p) }
            else if s.lowercased().hasPrefix("trojan://"),
               let p = parseTrojan(s) { result.append(p) }
            else if s.lowercased().hasPrefix("ss://"),
               let p = parseShadowsocks(s) { result.append(p) }
        }
        return result
    }

    // MARK: - VLESS
    private static func parseVLESS(_ link: String) -> VPNProfile? {
        guard let c = URLComponents(string: link) else { return nil }
        var q: [String: String] = [:]
        c.queryItems?.forEach { q[$0.name.lowercased()] = $0.value ?? "" }
        let name = (c.fragment?.removingPercentEncoding).flatMap { $0.isEmpty ? nil : $0 } ?? (c.host ?? "VLESS")

        return VPNProfile(
            name: name, type: "vless",
            server: c.host ?? "", port: c.port ?? 443,
            uuid: c.user, password: nil, method: nil,
            security: q["security"], sni: q["sni"], flow: q["flow"],
            network: q["type"] ?? "tcp",
            path: q["path"], serviceName: q["servicename"],
            pbk: q["pbk"], sid: q["sid"], fp: q["fp"] ?? "chrome",
            rawLink: link
        )
    }

    // MARK: - Hysteria2
    private static func parseHysteria2(_ link: String) -> VPNProfile? {
        guard let c = URLComponents(string: link) else { return nil }
        var q: [String: String] = [:]
        c.queryItems?.forEach { q[$0.name.lowercased()] = $0.value ?? "" }
        let name = (c.fragment?.removingPercentEncoding).flatMap { $0.isEmpty ? nil : $0 } ?? (c.host ?? "Hysteria2")

        return VPNProfile(
            name: name, type: "hysteria2",
            server: c.host ?? "", port: c.port ?? 443,
            uuid: nil, password: c.user?.removingPercentEncoding, method: nil,
            security: q["security"] ?? "tls", sni: q["sni"], flow: nil,
            network: nil, path: q["path"], serviceName: nil,
            pbk: nil, sid: nil, fp: q["fp"],
            rawLink: link
        )
    }

    // MARK: - Trojan
    private static func parseTrojan(_ link: String) -> VPNProfile? {
        guard let c = URLComponents(string: link) else { return nil }
        var q: [String: String] = [:]
        c.queryItems?.forEach { q[$0.name.lowercased()] = $0.value ?? "" }
        let name = (c.fragment?.removingPercentEncoding).flatMap { $0.isEmpty ? nil : $0 } ?? (c.host ?? "Trojan")

        return VPNProfile(
            name: name, type: "trojan",
            server: c.host ?? "", port: c.port ?? 443,
            uuid: nil, password: c.user?.removingPercentEncoding, method: nil,
            security: q["security"] ?? "tls", sni: q["sni"], flow: nil,
            network: q["type"] ?? "tcp", path: q["path"], serviceName: q["servicename"],
            pbk: q["pbk"], sid: q["sid"], fp: q["fp"],
            rawLink: link
        )
    }

    // MARK: - Shadowsocks
    private static func parseShadowsocks(_ link: String) -> VPNProfile? {
        // ss://base64(method:password)@host:port#name
        let stripped = link.replacingOccurrences(of: "ss://", with: "")
        let parts = stripped.split(separator: "#", maxSplits: 1).map(String.init)
        let name = parts.count > 1 ? parts[1].removingPercentEncoding ?? "SS" : "SS"
        let body = parts[0]

        let atParts = body.split(separator: "@", maxSplits: 1).map(String.init)
        guard atParts.count == 2 else { return nil }

        var method = ""
        var password = ""
        let cred = atParts[0]
        if let decoded = Data(base64Encoded: cred, options: .ignoreUnknownCharacters),
           let s = String(data: decoded, encoding: .utf8),
           let sep = s.firstIndex(of: ":") {
            method = String(s[..<sep]); password = String(s[s.index(after: sep)...])
        } else if let sep = cred.firstIndex(of: ":") {
            method = String(cred[..<sep]); password = String(cred[cred.index(after: sep)...])
        }

        let hp = atParts[1].split(separator: ":", maxSplits: 1).map(String.init)
        let host = hp.first ?? ""
        let port = Int(hp.count > 1 ? hp[1] : "443") ?? 443

        return VPNProfile(
            name: name, type: "ss",
            server: host, port: port,
            uuid: nil, password: password, method: method,
            security: nil, sni: nil, flow: nil, network: nil,
            path: nil, serviceName: nil, pbk: nil, sid: nil, fp: nil,
            rawLink: link
        )
    }
}
