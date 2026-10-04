import Foundation

struct VPNProfile: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var type: String          // vless, hysteria2, ss, trojan
    var server: String
    var port: Int
    var uuid: String?
    var password: String?
    var method: String?       // для shadowsocks
    var security: String?     // tls / reality / none
    var sni: String?
    var flow: String?
    var network: String?      // tcp / grpc / ws / xhttp
    var path: String?
    var serviceName: String?
    var pbk: String?
    var sid: String?
    var fp: String?
    var rawLink: String       // исходная ссылка

    var subtitle: String {
        "\(type.uppercased()) • \(server):\(port)"
    }
}

final class ProfileStore {
    static let shared = ProfileStore()
    private let key = "saved_profiles_v1"

    private(set) var profiles: [VPNProfile] = []

    private init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([VPNProfile].self, from: data) else {
            profiles = []
            return
        }
        profiles = arr
    }

    func save(_ list: [VPNProfile]) {
        profiles = list
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ newItems: [VPNProfile]) {
        var current = profiles
        current.append(contentsOf: newItems)
        save(current)
    }

    func removeAll() { save([]) }
}
