# FreePN

An Android-first Flutter starter for a local WireGuard VPN client.

## Current scope

- Phase 1: Flutter project structure
- Phase 2: Basic responsive connection UI
- Phase 3: `VpnService` abstraction backed by a Flutter method channel
- Phase 4: Android VPN permission flow and official WireGuard tunnel backend
- Phase 5: Runtime WireGuard keys and complete local client configuration
- Phase 6: [Windows laptop server setup guide](docs/local-wireguard-server-windows.md)
- Phase 7: basic real-device connectivity and disconnect/reconnect verified; see the [test record and alternate-route caveat](docs/local-connectivity-test.md#live-test-record-2026-09-29)

The app builds a complete configuration at runtime and passes it to the existing
Android permission flow and official WireGuard tunnel backend.

Phase 8 is in progress. If disconnect fails or Android does not confirm a
disconnected state, the UI warns that the tunnel may still be active and keeps
Disconnect available for retry. Connect, endpoint editing, and key editing stay
disabled until a retry confirms disconnection. The duration freezes on failure
and resets only after confirmed disconnection.

The screen checks Android's reported status on startup, when returning to the
app, and when tapping **Refresh status** in the top bar. Controls are locked
while that check runs (up to five seconds). An unavailable, unknown, or error
status offers Refresh or Disconnect for recovery instead of assuming the tunnel
is down. Confirmed external disconnection resets the timer and unlocks settings.
Status checks do not overlap an app-initiated connect/disconnect operation.
These checks use the native manager's reported tunnel state; they do not prove
server reachability or restore the elapsed connection time across process
restarts.

While connected, the app checks the local Wi-Fi/Ethernet network and the
WireGuard peer handshake every five seconds. It warns after 30 seconds without
a handshake and when the local network disappears. A tunnel can be active
without a working server connection; these warnings do not distinguish a wrong
key from a stopped server or blocked endpoint. Peer checks do not ping the
server and a recent handshake does not guarantee application traffic works.

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
traffic was verified. After laptop setup, follow the
[Phase 7 checklist](docs/local-connectivity-test.md) to verify reachability of
`10.10.0.1`, disconnect, and reconnect on a real Android device. Debug builds
emit non-secret permission/tunnel event logs under the `FreePN` logcat tag.

Do not place private keys or real WireGuard `.conf` files in this repository.

## Checks

Android builds require JDK 17 or newer.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```
