# Phase 7: first local connectivity test

Goal: verify a real Android phone can reach the laptop at `10.10.0.1`
through WireGuard, then disconnect and reconnect.

**Status: live connectivity is not yet verified.** When this phase was prepared,
ADB detected no device, WireGuard was absent from its default Windows install
location, and no WireGuard service or UDP 51820 listener was detected.
Automated Flutter tests use a fake VPN service or mocked platform channel;
they do not establish a real tunnel.

## Prerequisites

Complete the [Windows server guide](local-wireguard-server-windows.md).
Activate only `freepn-server` on the laptop, with `10.10.0.1/24` and the
correct client public key. Leave the client key-holder tunnel inactive.

Use a physical Android phone on the same trusted LAN as the laptop. Keep the
laptop awake and disable other VPN apps for this test. Keep routing limited
to `10.10.0.0/24`. No internet forwarding or NAT is required.

Enable Developer options and USB debugging on the phone, connect a USB data
cable, and approve the debugging authorization prompt. In PowerShell:

```powershell
$freepnAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
& $freepnAdb devices -l
```

If the SDK is elsewhere, adjust that path. The phone must show state `device`,
not `unauthorized` or `offline`. Copy its serial into the following variable,
then run from the project root:

```powershell
$freepnSerial = 'REPLACE_WITH_PHONE_SERIAL'
flutter run -d $freepnSerial
```

Keep that terminal open. These commands follow the
[Android ADB documentation](https://developer.android.com/tools/adb).

## Capture focused debug logs

In another PowerShell terminal, define the same ADB path and serial and run:

```powershell
$freepnAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$freepnSerial = 'REPLACE_WITH_PHONE_SERIAL'
& $freepnAdb -s $freepnSerial logcat -v time 'FreePN:D' '*:S'
```

Start observing before tapping Connect. Use timestamps to distinguish this
attempt from older buffered logs. Ctrl+C stops the log viewer, not the VPN.
See [Android's logcat filtering reference](https://developer.android.com/tools/logcat).

The app's `FreePN` tag logs only in debuggable builds. It records fixed event
names, tunnel states, and app-defined error codes. It does not print keys,
configuration text, endpoints, or exception messages. This follows
[Android's guidance on sensitive logging](https://developer.android.com/privacy-and-security/risks/log-info-disclosure).
Other tags from Android or the WireGuard dependency are outside this filter;
inspect any broader logs before sharing them.

## 1. Check the baseline

On the laptop, in administrator PowerShell:

```powershell
Get-NetIPAddress -InterfaceAlias 'freepn-server' -AddressFamily IPv4
Get-NetUDPEndpoint -LocalPort 51820
& 'C:\Program Files\WireGuard\wg.exe' show freepn-server
```

Confirm `10.10.0.1/24`, listen port `51820`, and peer allowed IP
`10.10.0.2/32`. A UDP listener alone does not prove reachability.

With FreePN disconnected, run a phone-side baseline:

```powershell
& $freepnAdb -s $freepnSerial shell ping -c 4 -W 2 10.10.0.1
```

This should fail in the intended isolated setup. If it succeeds before the VPN
is active, investigate another VPN or overlapping LAN routes; a later successful
ping would not by itself prove FreePN carried the traffic.

## 2. Connect and confirm the assigned address

In FreePN, enter the laptop's actual LAN IPv4 address and `:51820`.
Use **Configure WireGuard keys** to enter the client private key and server
public key. Do not place keys in shell commands or test reports.

Tap **Connect** and allow the Android VPN permission prompt if shown.
Permission can already be granted from an earlier run.

Expected debug events include:

```text
CONNECT_REQUESTED
VPN_PERMISSION_REQUESTED
VPN_PERMISSION_GRANTED
TUNNEL_STARTING
CONFIGURATION_PARSED
TUNNEL_STATE_UP
TUNNEL_START_COMPLETED
```

If permission was already granted, expect `VPN_PERMISSION_ALREADY_GRANTED`
instead of the request/granted pair. Callback timing can affect event order.

Confirm the phone actually has the configured address:

```powershell
& $freepnAdb -s $freepnSerial shell ip -4 address show
```

Look for `10.10.0.2/24` on the VPN interface; do not assume its name is
`tun0`. FreePN's displayed VPN IP is configuration, not a live address query.
If the device restricts this shell command, record that limitation rather than
treating the UI label as evidence. This address is statically configured, not
leased by DHCP.

## 3. Prove phone-to-laptop traffic

Run from the phone through ADB:

```powershell
& $freepnAdb -s $freepnSerial shell ping -c 4 -W 2 10.10.0.1
```

Expect replies from `10.10.0.1` and ideally 0% packet loss. If the first attempt
times out while the handshake starts, retry once and record both results.
This is a phone-shell test, not a built-in FreePN ping operation.

Immediately check the laptop:

```powershell
& 'C:\Program Files\WireGuard\wg.exe' show freepn-server
```

Compare the correct client's latest handshake and received/sent byte counters
before and after ping. A recent handshake plus successful ping and increasing
traffic is the required evidence. WireGuard's
[Windows status documentation](https://git.zx2c4.com/wireguard-windows/about/docs/enterprise.md)
describes this output.

Do not count these as success on their own:

- FreePN displaying **Connected**: it only confirms local tunnel activation.
- A laptop ping to its own VPN address.
- A historical handshake with no new traffic.
- General internet browsing or DNS results.

## 4. Disconnect and reconnect

Tap **Disconnect** in FreePN. Expect `DISCONNECT_REQUESTED`,
`TUNNEL_STATE_DOWN`, and `TUNNEL_STOP_COMPLETED`; an already-stopped tunnel
can report `TUNNEL_ALREADY_DOWN`.

Repeat the phone address and ping checks. The VPN address should disappear,
and reaching `10.10.0.1` should fail as it did at baseline.
The server may retain the old handshake timestamp; it is not proof of a
currently active client.

Tap **Connect** again without changing keys. Repeat the address check, ping,
and server counter comparison. Confirm a new handshake and successful traffic.

Keep the app process running for this reconnect test. If the process restarts,
the runtime keys must be entered again.

## Record the result

Copy this checklist into your local test notes. Leave untested rows unverified.
Record device model, Android version, build commit, date, ping summary, and
whether counters increased. Do not record private keys or complete configs.

| Check | Required evidence | Current live result |
| --- | --- | --- |
| Permission | Approved prompt or already-granted event | Unverified |
| Server address | Laptop adapter has 10.10.0.1/24 | Unverified |
| Client address | Phone VPN interface has 10.10.0.2/24 | Unverified |
| Activation | Native UP event and app Connected | Unverified |
| Handshake | Recent timestamp for the matching peer | Unverified |
| Reachability | Phone ping replies and traffic counters increase | Unverified |
| Disconnect | Native DOWN, address removed, ping stops | Unverified |
| Reconnect | Address restored, fresh handshake, ping works | Unverified |

## If a check fails

- No phone detected: check cable, USB debugging, authorization, and USB drivers.
- No `CONNECT_REQUESTED`: the Flutter form may have rejected the input first.
- `VPN_PERMISSION_DENIED`: retry and approve the request.
- `INVALID_VPN_CONFIGURATION`: inspect local values without sharing the keys.
- UP but no handshake: check laptop LAN endpoint, UDP firewall rule, Wi-Fi
  isolation, server activation, and the two key-pair mappings.
- Handshake but no ping: check the Phase 6 ICMP rule, subnet overlap, and
  server peer allowed IP. Do not disable the firewall wholesale.
- If ADB-shell ping is restricted or routed differently on the device, record
  that and use a phone-side network diagnostic app permitted through the VPN,
  corroborating it with the server counters.
- UI and native state disagree after an external disconnect: use the native
  logs for evidence and record the lifecycle issue for investigation.

Stay on `feat/local-vpn-connectivity` until this basic test passes. After
recording the result and committing this phase, prepare
`feat/vpn-error-handling` for Phase 8. Full-tunnel routing remains deferred.
