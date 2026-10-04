import NetworkExtension
import SwiftyXrayKit

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var bridge: XrayBridge?

    override func startTunnel(
        options: [String : NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let configuration = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration

        guard let shareLink = configuration?["shareLink"] as? String,
              !shareLink.isEmpty else {
            completionHandler(PacketTunnelError.missingConfiguration)
            return
        }

        let settings = NEPacketTunnelNetworkSettings(
            tunnelRemoteAddress: "192.0.2.1"
        )

        let ipv4 = NEIPv4Settings(
            addresses: ["198.18.0.2"],
            subnetMasks: ["255.255.0.0"]
        )
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        settings.dnsSettings = dns
        settings.mtu = 1500

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else {
                completionHandler(PacketTunnelError.providerUnavailable)
                return
            }
            if let error {
                completionHandler(error)
                return
            }

            do {
                let dataDir = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                )[0].appendingPathComponent("Xray", isDirectory: true)

                try FileManager.default.createDirectory(
                    at: dataDir,
                    withIntermediateDirectories: true
                )

                let bridge = XrayBridge(packetFlow: self.packetFlow)
                var preset = XrayTuningPreset.mobile
                preset.memoryLimitMB = 30

                try bridge.start(
                    config: .url(shareLink),
                    dataDir: dataDir,
                    finalConfigPath: dataDir.appendingPathComponent("final.json"),
                    preset: preset,
                    configTransform: { config in
                        var result = config
                        result["log"] = ["loglevel": "warning"]
                        result["dns"] = [
                            "servers": ["1.1.1.1", "8.8.8.8"]
                        ]
                        return result
                    }
                )

                self.bridge = bridge
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        bridge?.stop()
        bridge = nil
        completionHandler()
    }

    override func handleAppMessage(
        _ messageData: Data,
        completionHandler: ((Data?) -> Void)? = nil
    ) {
        completionHandler?(messageData)
    }
}

enum PacketTunnelError: LocalizedError {
    case missingConfiguration
    case providerUnavailable

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "VPN configuration is missing."
        case .providerUnavailable:
            return "VPN provider is unavailable."
        }
    }
}
