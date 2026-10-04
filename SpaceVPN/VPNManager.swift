import Foundation
import NetworkExtension
import SwiftUI

@MainActor
final class VPNManager: ObservableObject {
    @Published var profiles: [VPNProfile] = []
    @Published var selectedID: UUID?
    @Published var status: NEVPNStatus = .disconnected
    @Published var errorMessage: String?

    private var manager: NETunnelProviderManager?

    init() {
        loadSavedProfiles()
        Task { await refreshStatus() }
    }

    func importText(_ text: String) {
        let parsed = ShareLinkParser.parse(text)
        guard !parsed.isEmpty else {
            errorMessage = "Не удалось найти VPN-ссылку или Base64-конфигурацию."
            return
        }
        profiles.append(contentsOf: parsed)
        selectedID = profiles.last?.id
        saveProfiles()
    }

    func connect() {
        guard let profile = profiles.first(where: { $0.id == selectedID }) else {
            errorMessage = "Сначала выбери сервер."
            return
        }

        Task {
            do {
                let manager = try await loadManager()
                let proto = NETunnelProviderProtocol()
                proto.providerBundleIdentifier = "com.spacevpn.client.PacketTunnel"
                proto.serverAddress = profile.address
                proto.providerConfiguration = [
                    "shareLink": profile.raw,
                    "routing": "global"
                ]
                proto.disconnectOnSleep = false

                manager.protocolConfiguration = proto
                manager.localizedDescription = "SpaceVPN"
                manager.isEnabled = true
                try await manager.saveToPreferences()
                try await manager.loadFromPreferences()
                try manager.connection.startVPNTunnel()
                self.manager = manager
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }

    func refreshStatus() async {
        do {
            let m = try await loadManager()
            manager = m
            status = m.connection.status
        } catch {
            // No VPN profile yet is a normal first-run state.
        }
    }

    private func loadManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let existing = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                .providerBundleIdentifier == "com.spacevpn.client.PacketTunnel"
        }) {
            return existing
        }
        return NETunnelProviderManager()
    }

    private func loadSavedProfiles() {
        if let data = UserDefaults.standard.data(forKey: "profiles"),
           let decoded = try? JSONDecoder().decode([VPNProfile].self, from: data) {
            profiles = decoded
            selectedID = decoded.first?.id
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "profiles")
        }
    }
}
