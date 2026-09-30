# Phase 9: validation of the current Android build

Automated checks on 2026-09-30: `flutter test` passed 46 tests,
`flutter analyze` reported no issues, and `flutter build apk --debug` produced
`build/app/outputs/flutter-apk/app-debug.apk`. These checks do not establish a
real VPN connection. The Phase 8 build has **not yet been retested on a phone**.
The earlier [Phase 7 live test](local-connectivity-test.md#live-test-record-2026-09-29)
verified local connectivity on an older build.

## Real-device checklist (pending)

Use the same Windows server and physical Android phone as in the
[Phase 7 checklist](local-connectivity-test.md). From the project root, verify
the phone appears in `flutter devices`, then run the current build with
`flutter run -d <device-id>`. With wireless debugging, keep both devices on
the same trusted Wi-Fi and the laptop server active. Confirm the laptop's
current LAN IPv4 address before entering the `:51820` endpoint. Enter the
client private key and server public key **only in the app**; never put them
in commands, screenshots, logs, or this repository.

Record pass/fail and any non-secret observations for each check:

- [ ] Connect with the correct endpoint and keys. The app shows **Connected**
  and then **Server handshake verified.** Confirm a fresh handshake and
  increasing transfer counters with administrator PowerShell:
  `& 'C:\Program Files\WireGuard\wg.exe' show freepn-server`.
- [ ] While connected, run the phone-side address and ping checks from the
  Phase 7 guide. Confirm `10.10.0.2/24`, successful ping to `10.10.0.1`, and
  increased server counters. A ping alone is insufficient because this LAN
  previously had an alternate route to `10.10.0.1` without the VPN.
- [ ] Tap **Disconnect**. Confirm the VPN address disappears. Tap **Connect**
  again, and verify a new handshake and transfer. Do not interpret an old
  server handshake timestamp as proof the client is still connected.
- [ ] Background and reopen FreePN while connected, then tap **Refresh status**.
  Confirm the screen recovers the current tunnel state without showing a
  false disconnection. Repeat after disconnecting.
- [ ] To exercise the unreachable-endpoint warning, disconnect, change only
  the endpoint port to an unused port (for example `51821` if the server still
  listens on `51820`), and reconnect. After roughly 30 seconds, expect
  **No server handshake yet.** The local tunnel may still say **Connected**;
  that is not a successful server connection. Disconnect and restore `:51820`,
  then confirm a fresh handshake again.
- [ ] Optional: while connected, turn off phone Wi-Fi and check for
  **No Wi-Fi or Ethernet network is available.** Wireless ADB will disconnect,
  so observe this on the phone itself. Restore Wi-Fi and confirm recovery.

If a check fails, record the exact visible message and relevant non-secret
server status. Do not mark the real-device validation complete until the
updated build passes. Phase 10 full-tunnel routing is a separate later phase;
this build routes only `10.10.0.0/24` through the VPN.
