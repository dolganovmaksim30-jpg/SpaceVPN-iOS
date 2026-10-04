import NetworkExtension
import SwiftyXrayKit

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private var bridge: XrayBridge?

    private lazy var dataDir: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("xray", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override func startTunnel(options: [String : NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        guard let proto = protocolConfiguration as? NETunnelProviderProtocol,
              let rawLink = proto.providerConfiguration?["rawLink"] as? String,
              !rawLink.isEmpty else {
            completionHandler(NSError(domain: "PacketTunnel", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No rawLink in providerConfiguration"]))
            return
        }

        // Сетевые настройки туннеля
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
                let configPath = self.dataDir.appendingPathComponent("config.json")
                let bridge = XrayBridge(packetFlow: self.packetFlow)

                try bridge.start(
                    config: .url(rawLink),
                    dataDir: self.dataDir,
                    finalConfigPath: configPath,
                    sniffing: nil,
                    preset: .mobile,
                    configTransform: nil,
                    traceHandle: { msg in NSLog("[Xray] %@", msg) }
                )

                self.bridge = bridge
                completionHandler(nil)
            } catch {
                NSLog("[Xray] start failed: %@", String(describing: error))
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        bridge?.stop()
        bridge = nil
        completionHandler()
    }
}
