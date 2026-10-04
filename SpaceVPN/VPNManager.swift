import Foundation
import NetworkExtension

enum TunnelState {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error
}

@MainActor
final class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var state: TunnelState = .disconnected
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusChanged),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }

    @objc private func statusChanged() {
        refreshFromManager()
    }

    func refreshFromManager() {
        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            guard let m = managers?.first else {
                DispatchQueue.main.async { self.state = .disconnected }
                return
            }
            DispatchQueue.main.async { self.manager = m; self.applyStatus(m.connection.status) }
        }
    }

    private func applyStatus(_ s: NEVPNStatus) {
        switch s {
        case .connected:        state = .connected
        case .connecting:       state = .connecting
        case .disconnecting:    state = .disconnecting
        case .disconnected, .invalid: state = .disconnected
        case .reasserting:      state = .connecting
        @unknown default:       state = .disconnected
        }
    }

    func toggle(profile: VPNProfile) {
        if state == .connected || state == .connecting {
            stop()
        } else {
            start(profile: profile)
        }
    }

    func start(profile: VPNProfile) {
        state = .connecting
        NETunnelProviderManager.loadAllFromPreferences { managers, _ in
            let mgr = managers?.first ?? NETunnelProviderManager()
            mgr.protocolConfiguration = self.makeProtocol(for: profile)
            mgr.localizedDescription = "SpaceVPN"
            mgr.isEnabled = true
            mgr.saveToPreferences { error in
                if let error = error {
                    DispatchQueue.main.async { self.state = .error; self.lastError = error.localizedDescription }
                    return
                }
                mgr.loadFromPreferences { _ in
                    do {
                        try mgr.connection.startVPNTunnel()
                        DispatchQueue.main.async { self.manager = mgr; self.state = .connecting }
                    } catch {
                        DispatchQueue.main.async { self.state = .error; self.lastError = error.localizedDescription }
                    }
                }
            }
        }
    }

    func stop() {
        state = .disconnecting
        manager?.connection.stopVPNTunnel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.state == .disconnecting { self.state = .disconnected }
        }
    }

    private func makeProtocol(for profile: VPNProfile) -> NETunnelProviderProtocol {
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.spacevpn.client.PacketTunnel"
        proto.serverAddress = profile.server
        proto.providerConfiguration = ["rawLink": profile.rawLink]
        return proto
    }
}
