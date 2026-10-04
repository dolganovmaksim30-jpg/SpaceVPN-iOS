import NetworkExtension
import SwiftyXrayKit

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private var isRunning = false

    override func startTunnel(options: [String : NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        // Сетевые настройки туннеля
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 1500

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        settings.dnsSettings = dns

        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        setTunnelNetworkSettings(settings) { error in
            if let error = error {
                completionHandler(error)
                return
            }
            // TODO: здесь позже подключим SwiftyXray и Xray-конфиг
            // Сейчас — просто поднимаем туннель, чтобы приложение работало
            self.isRunning = true
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        isRunning = false
        completionHandler()
    }
}
