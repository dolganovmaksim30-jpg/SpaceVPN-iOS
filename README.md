# SpaceVPN iOS

A clean iOS VPN client skeleton designed for sideloading through eSign.

## Architecture

- SwiftUI app
- `NetworkExtension` / `NEPacketTunnelProvider`
- `SwiftyXrayKit` / Xray TUN bridge
- Share-link import
- Base64 subscription decoding
- VLESS / VMess / Trojan / Shadowsocks / generic URL parsing
- Global / split routing modes
- DNS settings
- Server list and latency test
- GitHub Actions macOS build
- Unsigned IPA output for signing with eSign

## Important signing note

A VPN Packet Tunnel is not an ordinary iOS app. The final signing identity/profile must permit the
`com.apple.developer.networking.networkextension` entitlement with `packet-tunnel-provider`.

If eSign reports an install/signing error, the first thing to verify is that the certificate/profile
being used actually permits Network Extension. Re-signing an app with a certificate that does not
contain the required VPN entitlement cannot magically add that capability.

## Build from Windows

1. Create a GitHub repository.
2. Upload this project.
3. Push to `main`.
4. Open **Actions** -> **Build unsigned IPA**.
5. Download the `SpaceVPN-unsigned-ipa` artifact.
6. Sign the IPA with eSign on your iPhone.

The workflow uses a hosted macOS runner, so you do not need a Mac.

## Local development

A Mac with Xcode is still required for native local debugging of the Packet Tunnel.

## Protocol note

The UI accepts common share-link formats. The bundled Xray bridge is the runtime responsible for
actually supporting a protocol. The included SwiftyXrayKit release exposes the Apple-oriented Xray
features documented by its upstream project. Do not advertise a protocol as working merely because
its URL parser accepts it.

## Bundle IDs

Default:
- App: `com.spacevpn.client`
- Packet Tunnel: `com.spacevpn.client.PacketTunnel`

Change these in `project.yml` before using a production Apple Developer account.

## Security

Never put private signing certificates, `.p12` files, passwords, or provisioning profiles into
the repository.
