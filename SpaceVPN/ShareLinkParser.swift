import Foundation

enum ShareLinkParser {
    static func parse(_ input: String) -> [VPNProfile] {
        let normalized = input
            .replacingOccurrences(of: "\r", with: "\n")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        var candidates = normalized.filter {
            let lower = $0.lowercased()
            return lower.hasPrefix("vless://")
                || lower.hasPrefix("vmess://")
                || lower.hasPrefix("trojan://")
                || lower.hasPrefix("ss://")
                || lower.hasPrefix("socks://")
                || lower.hasPrefix("http://")
                || lower.hasPrefix("https://")
        }

        if candidates.isEmpty {
            let compact = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if let decoded = decodeBase64(compact) {
                candidates = decoded
                    .split(whereSeparator: \.isWhitespace)
                    .map(String.init)
            }
        }

        return candidates.compactMap(parseSingle)
    }

    private static func parseSingle(_ link: String) -> VPNProfile? {
        guard let url = URL(string: link), let scheme = url.scheme else { return nil }

        let proto = scheme.uppercased()
        let host = url.host ?? ""
        let port = url.port ?? defaultPort(for: scheme)

        guard !host.isEmpty else { return nil }

        let name: String = {
            if let fragment = url.fragment, !fragment.isEmpty {
                return fragment.removingPercentEncoding ?? fragment
            }
            return host
        }()

        return VPNProfile(
            name: name,
            address: host,
            port: port,
            protocolName: proto,
            raw: link
        )
    }

    private static func defaultPort(for scheme: String) -> Int {
        switch scheme.lowercased() {
        case "http", "https": return scheme.lowercased() == "https" ? 443 : 80
        case "ss", "socks": return 443
        default: return 443
        }
    }

    private static func decodeBase64(_ value: String) -> String? {
        var s = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }

        guard let data = Data(base64Encoded: s, options: [.ignoreUnknownCharacters]),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        return decoded
    }
}
