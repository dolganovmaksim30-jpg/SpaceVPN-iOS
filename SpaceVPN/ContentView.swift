import SwiftUI
import NetworkExtension

struct ContentView: View {
    @EnvironmentObject private var vpn: VPNManager
    @State private var importText = ""
    @State private var showingImport = false

    private var isConnected: Bool {
        vpn.status == .connected || vpn.status == .connecting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.black, Color(red: 0.07, green: 0.08, blue: 0.11)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        connectionCard
                        serverList
                        importCard
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingImport) {
                ImportView(text: $importText) {
                    vpn.importText(importText)
                    importText = ""
                    showingImport = false
                }
                .presentationDetents([.medium, .large])
            }
            .alert("SpaceVPN", isPresented: Binding(
                get: { vpn.errorMessage != nil },
                set: { if !$0 { vpn.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { vpn.errorMessage = nil }
            } message: {
                Text(vpn.errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("SpaceVPN")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Private connection")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 28))
        }
        .padding(.top, 18)
    }

    private var connectionCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 18)
                    .frame(width: 190, height: 190)
                Circle()
                    .stroke(isConnected ? .green : .white.opacity(0.25), lineWidth: 3)
                    .frame(width: 170, height: 170)

                VStack(spacing: 8) {
                    Image(systemName: isConnected ? "lock.fill" : "lock.open")
                        .font(.system(size: 34))
                    Text(isConnected ? "CONNECTED" : "DISCONNECTED")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }

            Button {
                if isConnected {
                    vpn.disconnect()
                } else {
                    vpn.connect()
                }
            } label: {
                Text(isConnected ? "Disconnect" : "Connect")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isConnected ? .white.opacity(0.10) : .white)
                    .foregroundStyle(isConnected ? .white : .black)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
        .padding(24)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var serverList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Servers")
                    .font(.headline)
                Spacer()
                Button("Add") { showingImport = true }
            }

            if vpn.profiles.isEmpty {
                Text("Import a VLESS / VMess / Trojan / Shadowsocks link or a Base64 subscription.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(vpn.profiles) { profile in
                    Button {
                        vpn.selectedID = profile.id
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "server.rack")
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .foregroundStyle(.white)
                                Text("\(profile.protocolName) • \(profile.address):\(profile.port)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if vpn.selectedID == profile.id {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding(16)
                        .background(.white.opacity(vpn.selectedID == profile.id ? 0.10 : 0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private var importCard: some View {
        Button { showingImport = true } label: {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                VStack(alignment: .leading) {
                    Text("Import configuration")
                        .fontWeight(.semibold)
                    Text("Share link, Base64 or subscription")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(18)
            .background(.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct ImportView: View {
    @Binding var text: String
    let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Paste configuration")
                    .font(.title2.bold())
                TextEditor(text: $text)
                    .padding(12)
                    .background(.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Button("Import") { onImport() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
