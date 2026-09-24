# FreePN

An Android-first Flutter starter for a local WireGuard VPN client.

## Current scope

- Phase 1: Flutter project structure
- Phase 2: Basic responsive connection UI
- Phase 3: `VpnService` abstraction backed by a Flutter method channel
- Phase 4: Android VPN permission flow and official WireGuard tunnel backend
- Phase 5: Runtime WireGuard keys and complete local client configuration
- Phase 6: [Windows laptop server setup guide](docs/local-wireguard-server-windows.md)

The app builds a complete configuration at runtime and passes it to the existing
Android permission flow and official WireGuard tunnel backend.

## Local development configuration

1. Follow the [Phase 6 Windows server guide](docs/local-wireguard-server-windows.md)
   to configure the laptop and generate separate server/client key pairs.
   The server peer must use the **client public key**. A placeholder-only
   [server configuration](config/freepn-server.conf.example) is included.
2. On Android, enter your laptop's current LAN IPv4 address or hostname and port
   in **Server endpoint**, for example `192.168.1.10:51820`.
3. Open **Configure WireGuard keys**. Enter the **client private key** and
   **server public key**, then choose **Use keys**. Do not enter the server's
   private key into the app.
4. Tap **Connect** and approve Android's VPN permission request. Disconnect and
   reconnect use the same keys during this app session.

The configuration uses client address `10.10.0.2/24`, DNS `1.1.1.1`,
`AllowedIPs = 10.10.0.0/24`, and keepalive `25`. Only the VPN subnet is routed
through the tunnel; internet forwarding/NAT is not enabled. The DNS address is
outside that subnet, so DNS behavior depends on Android's underlying network;
use the numeric server VPN address `10.10.0.1` for the first connectivity test.

Keys are entered at runtime, held in memory, and never written to app storage,
assets, build defines, or logs by this app. The private-key field is masked.
Re-enter keys after the app process restarts. This does not protect against a
compromised device, memory inspection, or a clipboard that retained pasted keys.
Key validation checks encoding, not whether the client/server key pairs match.

Do not pass keys through `--dart-define` or bundle them in an APK. Existing Git
ignore rules exclude `*.conf`, `*.key`, and `.env*`; keep generated credentials
outside the repository. Tests use synthetic key bytes only.

**Connected** means Android activated the tunnel, not that a server handshake or
traffic was verified. Phase 6 is laptop setup; Phase 7 verifies reachability of
`10.10.0.1`, disconnect, and reconnect on a real Android device.

Do not place private keys or real WireGuard `.conf` files in this repository.

## Checks

Android builds require JDK 17 or newer.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```
