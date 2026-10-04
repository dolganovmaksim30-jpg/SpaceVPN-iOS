import Foundation

struct VPNProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var port: Int
    var protocolName: String
    var raw: String

    init(name: String, address: String, port: Int, protocolName: String, raw: String) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.port = port
        self.protocolName = protocolName
        self.raw = raw
    }
}
