import NetworkExtension
import SwiftyXrayKit

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private var bridge: XrayBridge?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // 1. Настраиваем сетевые параметры туннеля (DNS, маршруты)
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 1500

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        settings.dnsSettings = dns

        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()] // Весь трафик -> в туннель
        settings.ipv4Settings = ipv4

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self, error == nil else {
                completionHandler(error)
                return
            }
            do {
                // 2. Запускаем Xray-ядро
                try self.startXray()
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    private func startXray() throws {
        // 3. Читаем конфиг из providerConfiguration (его туда положил VPNManager)
        guard let proto = self.protocolConfiguration as? NETunnelProviderProtocol,
              let rawLink = proto.providerConfiguration?["rawLink"] as? String else {
            throw NSError(domain: "PacketTunnel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No rawLink in provider configuration"])
        }

        // 4. Пути для данных и финального конфига
        let dataDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let finalConfigURL = dataDir.appendingPathComponent("final_config.json")

        // 5. Создаём мост и запускаем Xray
        let bridge = XrayBridge(packetFlow: packetFlow)
        try bridge.start(
            config: .url(rawLink), // Прямая ссылка на сервер (vless://...)
            dataDir: dataDir,
            finalConfigPath: finalConfigURL,
            preset: .mobile // Критически важно для iOS (лимит памяти)
        )
        self.bridge = bridge
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        bridge?.stop()
        bridge = nil
        completionHandler()
    }
}
