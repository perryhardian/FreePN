# Phase 7: first local connectivity test

Goal: verify a real Android phone can reach the laptop at `10.10.0.1`
through WireGuard, then disconnect and reconnect.

**Status: basic live connectivity and disconnect/reconnect verified from
user-supplied device and server output, recorded on 2026-09-29.** See the test
record below for evidence and the alternate-route caveat.
Automated Flutter tests use a fake VPN service or mocked platform channel;
they do not establish a real tunnel.

## Prerequisites

Complete the [Windows server guide](local-wireguard-server-windows.md).
Activate only `freepn-server` on the laptop, with `10.10.0.1/24` and the
correct client public key. Leave the client key-holder tunnel inactive.

Use a physical Android phone on the same trusted LAN as the laptop. Keep the
laptop awake and disable other VPN apps for this test. Keep routing limited
to `10.10.0.0/24`. No internet forwarding or NAT is required.

Enable Developer options and connect through USB debugging or pair and connect
through Android wireless debugging. This test used wireless debugging because
USB was unavailable. In PowerShell:

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

Repeat the phone address and ping checks. The VPN address should disappear.
If the destination is unreachable outside the VPN, ping should fail as at
baseline. If ping still succeeds, inspect the disconnected route and compare
server traffic counters during connected tests; do not assume the VPN remains
active. See the alternate-route finding below.
The server may retain the old handshake timestamp; it is not proof of a
currently active client.

Tap **Connect** again without changing keys. Repeat the address check, ping,
and server counter comparison. Confirm a new handshake and successful traffic.

Keep the app process running for this reconnect test. If the process restarts,
the runtime keys must be entered again.

## Live test record: 2026-09-29

Evidence comes from commands run by the user and pasted into the project
conversation. Phone: Samsung SM A336E, Android 14 (API 34), connected through
wireless ADB. App: Flutter debug build. Repository HEAD when recording was
`f19df42` (VPN connectivity diagnostics); the installed APK's exact commit was
not independently verified. No private keys or full configurations are included.

| Check | Required evidence | Current live result |
| --- | --- | --- |
| Permission | Approved prompt or already-granted event | Permission flow not separately captured; successful tunnel operation confirms permission was available |
| Server address | Laptop adapter has 10.10.0.1/24 | User reported Phase 6 completion; adapter output not captured; connected traffic to 10.10.0.1 verified |
| Client address | Phone VPN interface has 10.10.0.2/24 | Verified on active tun0 after reconnect, MTU 1280 |
| Activation | App Connected and live tunnel evidence | User reported Connected; tun0, handshake, and traffic verified; native UP log not captured |
| Handshake | Recent timestamp for the matching peer | Verified: 7 seconds old after reconnect; 56 seconds old at subsequent counter check |
| Reachability | Phone ping replies and traffic counters increase | Verified: 10 sent, 10 received, 0% loss; counters increased as detailed below |
| Disconnect | VPN interface and address removed | Verified: only lo and wlan0 remained; ping used an alternate route; native DOWN log not captured |
| Reconnect | Address restored, fresh handshake, ping works | Verified: tun0 restored, fresh handshake, 10 successful pings, and increased counters |

### Issues resolved during the test

- The laptop's Wi-Fi address changed from `192.168.1.4` to `192.168.1.9`.
  Updating FreePN's endpoint to `192.168.1.9:51820` produced a handshake.
  These are observed test addresses, not permanent defaults.
- The `FreePN-VPN-Ping` firewall rule was missing. After creating the Phase 6
  rule (ICMPv4 echo requests from `10.10.0.2` to `10.10.0.1`), connected ping
  changed from 4/4 lost to 4/4 received, with replies showing TTL 128.
- Reading server status required administrator PowerShell.

### Reconnect traffic evidence

The phone's LAN address was `192.168.1.10/24`. After reconnect, the server
reported that peer at UDP endpoint `192.168.1.10:41998`, with allowed IP
`10.10.0.2/32` and a handshake 7 seconds old.

| Server counter | Before 10 pings | After 10 pings |
| --- | --- | --- |
| Received | 1.71 KiB | 3.03 KiB |
| Sent | 820 B | 2.05 KiB |

Phone-side ping to `10.10.0.1`: 10 transmitted, 10 received, 0% packet loss;
RTT min/avg/max was 4.813/14.860/18.164 ms, with TTL 128 in every reply.
Together with the fresh handshake and active `tun0` address, the increased
bidirectional counters corroborate traffic through WireGuard. Counter deltas
can include keepalives and handshake traffic, not just ping payloads.

### Alternate-route caveat

After disconnect, the phone had only `lo` and `wlan0`; `10.10.0.2` and the VPN
interface were absent. However, 4/4 pings to `10.10.0.1` still received replies,
now with TTL 63. The disconnected route query returned:

```text
10.10.0.1 via 192.168.1.1 dev wlan0 table 1023 src 192.168.1.10 uid 2000
```

This confirms an alternate route through the Wi-Fi gateway. The identity of
the responder beyond that gateway is unknown; the TTL difference alone does
not identify it. This is an address/routing overlap to investigate, not evidence
that FreePN's VPN interface remained active.

For this test, disconnect is supported by interface removal and reconnection
by interface restoration, handshake, and traffic evidence. Before relying on
ping failure as an isolation check, choose a VPN subnet verified to be unused
on this network and update both client and server consistently. No subnet or
full-tunnel changes were made as part of recording these results.

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
