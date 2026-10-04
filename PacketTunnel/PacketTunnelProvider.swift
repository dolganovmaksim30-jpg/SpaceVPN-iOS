import NetworkExtension
import SwiftyXrayKit

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private var isRunning = false

    private lazy var dataDir: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("xray", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override func startTunnel(options: [String : NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        // 1. Читаем rawLink из providerConfiguration
        guard let proto = protocolConfiguration as? NETunnelProviderProtocol,
              let rawLink = proto.providerConfiguration?["rawLink"] as? String,
              !rawLink.isEmpty else {
            completionHandler(NSError(domain: "PacketTunnel", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No rawLink in providerConfiguration"]))
            return
        }

        // 2. Настраиваем сетевой интерфейс туннеля
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 1500
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])

        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self, error == nil else {
                completionHandler(error)
                return
            }
            do {
                try self.startXray(rawLink: rawLink)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    // MARK: - Запуск Xray

    private func startXray(rawLink: String) throws {
        // 1. Ссылка → готовый JSON Xray
        var jsonString = try SwiftyXray.xrayShareLinkToJson(url: rawLink)

        // 2. Заменяем inbound на TUN (по умолчанию share-link даёт SOCKS)
        guard var config = try JSONSerialization.jsonObject(with: Data(jsonString.utf8)) as? [String: Any] else {
            throw NSError(domain: "PacketTunnel", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Cannot parse xray config"])
        }

        let tunInbound: [String: Any] = [
            "tag": "tun-in",
            "protocol": "tun",
            "settings": [
                "domainStrategy": "UseIP",
                "sniffing": [
                    "enabled": true,
                    "destOverride": ["http", "tls", "quic"]
                ]
            ]
        ]
        config["inbounds"] = [tunInbound]
        config["log"] = ["loglevel": "warning"]

        let newData = try JSONSerialization.data(withJSONObject: config)
        jsonString = String(data: newData, encoding: .utf8) ?? jsonString

        // 3. Пишем config.json
        let configPath = dataDir.appendingPathComponent("config.json")
        try jsonString.write(to: configPath, atomically: true, encoding: .utf8)

        // 4. Получаем файловый дескриптор TUN из packetFlow
        //    "socket" — стандартный приём для iOS VPN-клиентов
        guard let tunFd = packetFlow.value(forKey: "socket") as? Int32 else {
            throw NSError(domain: "PacketTunnel", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Cannot get tun fd from packetFlow"])
        }

        // 5. Настройки памяти и сокетов (важно для iOS extension — лимит ~50MB)
        SwiftyXray.setTunFd(tunFd)
        SwiftyXray.setMemoryLimitMB(30)
        SwiftyXray.setTCPBufMaxKB(64)
        SwiftyXray.setTCPMaxInFlight(512)
        SwiftyXray.setMaxUDPConns(128)

        // 6. Запускаем
        try SwiftyXray.run(
            dataDir: dataDir.path,
            configPath: configPath.path,
            traceHandle: { msg in NSLog("[Xray] \(msg)") }
        )

        isRunning = true
    }

    // MARK: - Остановка

    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        if isRunning {
            try? SwiftyXray.stop()
            isRunning = false
        }
        completionHandler()
    }
}
