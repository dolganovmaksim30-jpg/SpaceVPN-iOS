import SwiftUI

struct ContentView: View {
    @StateObject private var vpn = VPNManager.shared
    @State private var profiles: [VPNProfile] = ProfileStore.shared.profiles
    @State private var selected: VPNProfile? = ProfileStore.shared.profiles.first
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    header

                    statusCircle
                        .padding(.top, 12)

                    connectButton

                    Spacer(minLength: 8)

                    serversSection

                    importButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .onAppear {
                vpn.refreshFromManager()
                reloadProfiles()
            }
            .sheet(isPresented: $showImport) {
                ImportView { newOnes in
                    ProfileStore.shared.add(newOnes)
                    reloadProfiles()
                    if selected == nil { selected = newOnes.first }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SpaceVPN")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                Text("Private connection")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 26))
                .foregroundColor(.white)
        }
        .padding(.top, 8)
    }

    // MARK: - Круг статуса с анимацией
    private var statusCircle: some View {
        ZStack {
            Circle()
                .fill(circleFillColor.opacity(0.10))
                .frame(width: 260, height: 260)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .animation(
                    isAnimating
                    ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                    : .default,
                    value: pulseScale
                )

            Circle()
                .stroke(circleStrokeColor, lineWidth: 3)
                .frame(width: 200, height: 200)

            VStack(spacing: 12) {
                Image(systemName: circleIcon)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundColor(circleStrokeColor)
                Text(stateLabel)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.white)
            }
        }
        .frame(height: 280)
        .onAppear { triggerPulse() }
        .onChange(of: vpn.state) { _ in triggerPulse() }
    }

    private var connectButton: some View {
        Button {
            guard let profile = selected else {
                showImport = true
                return
            }
            vpn.toggle(profile: profile)
        } label: {
            Text(buttonLabel)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(buttonColor)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(vpn.state == .connecting || vpn.state == .disconnecting)
    }

    // MARK: - Servers
    private var serversSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Servers")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if !profiles.isEmpty {
                    Button("Clear") {
                        ProfileStore.shared.removeAll()
                        reloadProfiles()
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
            }

            if profiles.isEmpty {
                Text("Пусто. Нажми «Import configuration» ниже.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(profiles) { p in
                            serverRow(p)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func serverRow(_ p: VPNProfile) -> some View {
        Button {
            selected = p
        } label: {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.subheadline).foregroundColor(.white).lineLimit(1)
                    Text(p.subtitle).font(.caption).foregroundColor(.gray)
                }
                Spacer()
                if selected?.id == p.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var importButton: some View {
        Button { showImport = true } label: {
            HStack {
                Image(systemName: "square.and.arrow.down")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import configuration")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Share link, Base64 or subscription")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.blue.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundColor(.blue)
        }
    }

    // MARK: - Helpers
    private func reloadProfiles() {
        ProfileStore.shared.load()
        profiles = ProfileStore.shared.profiles
        if selected == nil { selected = profiles.first }
    }

    private var stateLabel: String {
        switch vpn.state {
        case .disconnected:  return "DISCONNECTED"
        case .connecting:    return "CONNECTING…"
        case .connected:     return "CONNECTED"
        case .disconnecting: return "DISCONNECTING…"
        case .error:         return "ERROR"
        }
    }

    private var circleStrokeColor: Color {
        switch vpn.state {
        case .disconnected:  return Color.gray
        case .connecting, .disconnecting: return Color.yellow
        case .connected:     return Color.green
        case .error:         return Color.red
        }
    }

    private var circleFillColor: Color {
        circleStrokeColor
    }

    private var circleIcon: String {
        switch vpn.state {
        case .disconnected:  return "lock.open"
        case .connecting, .disconnecting: return "arrow.triangle.2.circlepath"
        case .connected:     return "lock.fill"
        case .error:         return "exclamationmark.triangle"
        }
    }

    private var buttonLabel: String {
        if selected == nil { return "Import a server" }
        switch vpn.state {
        case .disconnected, .error: return "Connect"
        case .connecting:           return "Connecting…"
        case .connected:            return "Disconnect"
        case .disconnecting:        return "Disconnecting…"
        }
    }

    private var buttonColor: Color {
        switch vpn.state {
        case .disconnected, .error: return .white
        case .connecting, .disconnecting: return .yellow
        case .connected: return .red
        }
    }

    private var isAnimating: Bool {
        vpn.state == .connecting || vpn.state == .disconnecting
    }

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.35

    private func triggerPulse() {
        if isAnimating {
            pulseScale = 1.12
            pulseOpacity = 0.7
        } else {
            pulseScale = 1.0
            pulseOpacity = vpn.state == .connected ? 0.5 : 0.2
        }
    }
}

// MARK: - Import View
struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url: String = ""
    @State private var isLoading = false
    @State private var message: String?
    @State private var imported: [VPNProfile] = []

    let onDone: ([VPNProfile]) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Вставь ссылку подписки или одиночную vless://")
                        .font(.footnote).foregroundColor(.gray)

                    TextField("https://… или vless://…", text: $url, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .lineLimit(4...10)

                    if let message {
                        Text(message).font(.footnote).foregroundColor(.yellow)
                    }

                    Button {
                        runImport()
                    } label: {
                        HStack {
                            if isLoading { ProgressView().tint(.black) }
                            Text(isLoading ? "Загрузка…" : "Импортировать")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isLoading || url.trimmingCharacters(in: .whitespaces).isEmpty)

                    if !imported.isEmpty {
                        Text("Найдено: \(imported.count)")
                            .foregroundColor(.green).font(.footnote)
                        Button("Сохранить и закрыть") {
                            onDone(imported); dismiss()
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    private func runImport() {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        message = nil
        imported = []

        // Одиночная ссылка (не http)
        if trimmed.contains("://") && !trimmed.lowercased().hasPrefix("http") {
            let parsed = ShareLinkParser.parseLines(trimmed)
            if parsed.isEmpty { message = "Не удалось распарсить ссылку" }
            else { imported = parsed }
            return
        }

        // Подписка по URL
        isLoading = true
        ShareLinkParser.fetchSubscription(urlString: trimmed) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let list):
                    if list.isEmpty { message = "Конфиги не найдены" }
                    else { imported = list }
                case .failure(let err):
                    message = "Ошибка: \(err.localizedDescription)"
                }
            }
        }
    }
}
