# Phase 6: Windows laptop WireGuard server

This guide prepares the server for the existing FreePN Android app. Run the OS
steps manually on your laptop. Completing this document does not mean a live
connection has been tested; that is Phase 7.

## 1. Install WireGuard and identify your LAN

Install the Windows application from the [official WireGuard download page](https://www.wireguard.com/install/).
Open WireGuard and allow the Windows administrator prompt.

Connect the phone and laptop to the same trusted LAN. Avoid guest Wi-Fi with
client isolation. Keep the laptop awake. No router port forwarding is needed
for this same-LAN test.

In PowerShell:

```powershell
Get-NetIPConfiguration
Get-NetConnectionProfile
```

Find the active Wi-Fi or Ethernet adapter with your LAN's default gateway.
Record its IPv4 address, interface alias, and network category. Do not select
a WSL, Hyper-V, loopback, or other VPN adapter.

For example, if the laptop address is `192.168.1.10`, enter
`192.168.1.10:51820` in FreePN. Use your actual address; it can change with DHCP.
The endpoint is the laptop's **LAN address**, not `10.10.0.1`.

The UDP firewall rule below uses the Private profile. If your trusted home LAN
is Public, change that network to Private in Windows Settings:
Network & internet > Wi-Fi (or Ethernet) > the connected network > Network
profile type. Do not reclassify a public or managed network just for this test.

Check that the LAN and other active VPNs do not already use `10.10.0.0/24`.
If they do, stop and choose a non-overlapping VPN subnet in both the app and
server configuration before testing.

## 2. Generate two separate key pairs

Use WireGuard's **Add Tunnel** dropdown > **Add empty tunnel**. Its editor
generates a private key and displays the corresponding public key. This
behavior is implemented in the [official Windows editor](https://github.com/WireGuard/wireguard-windows/blob/master/ui/editdialog.go).

First create a tunnel named `freepn-client-keys`:

1. Keep the generated `PrivateKey` line and add `Address = 10.10.0.2/24`
   under `[Interface]`.
2. Save this entry, but **leave it inactive on the laptop**. It is only a
   local development key holder for the Android client.
3. Copy its public key for the server's peer configuration.
4. Reopen **Edit** when you need its private key for FreePN on your phone.

Create another empty tunnel named `freepn-server`. Keep its newly generated
private key. Record its public key for FreePN.

Keep both entries so that restarting FreePN does not require generating new
keys. Changing the client key pair requires updating the server peer too.
Do not activate the client key-holder entry on Windows: the Android app owns
`10.10.0.2`.

| Key | Where it belongs |
| --- | --- |
| Server private key | Laptop: server `[Interface]` only |
| Server public key | FreePN: **Server public key** |
| Client private key | FreePN: **Client private key** |
| Client public key | Laptop: server `[Peer]` |

Transfer the client private key locally and privately; do not paste it into
chat, email, commits, screenshots, or issue reports. Clear any clipboard history
containing it after transfer. This development approach retains the client
private key on the laptop as well as in the running phone app.

## 3. Configure the server

In the `freepn-server` editor, use this configuration. Preserve the server's
generated private key and replace `CLIENT_PUBLIC_KEY` with the public key from
`freepn-client-keys`:

```ini
[Interface]
PrivateKey = SERVER_PRIVATE_KEY
Address = 10.10.0.1/24
ListenPort = 51820

[Peer]
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = 10.10.0.2/32
```

A copyable, placeholder-only [server example](../config/freepn-server.conf.example)
is included. The placeholders are deliberately invalid keys.

The server's peer identifies only the phone's VPN address. The app already
routes `10.10.0.0/24` to the server and sends keepalives every 25 seconds.
Do not add default routes, NAT, Internet Connection Sharing, or IP forwarding
for this laptop-only milestone.

### Where configuration files belong

On Windows, the GUI manages encrypted `.conf.dpapi` files in
`%ProgramFiles%\WireGuard\Data\Configurations\`. Edit through the GUI.
If importing a file instead, create a private local copy named
`freepn-server.conf` outside this repository, replace the placeholders, and
choose **Import tunnel(s) from file**. Treat the original plaintext file and
any exported archives as secrets. See [WireGuard's Windows storage documentation](https://git.zx2c4.com/wireguard-windows/about/docs/enterprise.md).

For a later Linux server, the conventional `wg-quick` location is
`/etc/wireguard/freepn-server.conf`, owned by root with mode `600`;
`sudo wg-quick up freepn-server` starts it and
`sudo wg-quick down freepn-server` stops it.
On macOS, use the official app's tunnel import/editor workflow; the Windows
firewall commands below do not apply.
See the [wg-quick manual](https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8).

## 4. Allow the local test through Windows Firewall

Open **PowerShell as Administrator**. Set the actual LAN interface alias from
step 1. Run each rule creation once. If a rule already exists, inspect its
settings instead of adding duplicates.

```powershell
$freepnLanInterface = 'Wi-Fi' # Replace with your actual LAN interface alias
New-NetFirewallRule -Name 'FreePN-WireGuard-LAN' -DisplayName 'FreePN WireGuard UDP from LAN' -Direction Inbound -Action Allow -Protocol UDP -LocalPort 51820 -RemoteAddress LocalSubnet -InterfaceAlias $freepnLanInterface -Profile Private
```

Prepare a narrowly scoped ping rule for Phase 7. The VPN adapter may use a
different network profile, so this rule uses Any but is restricted to the
server and client VPN addresses:

```powershell
New-NetFirewallRule -Name 'FreePN-VPN-Ping' -DisplayName 'FreePN VPN client ping' -Direction Inbound -Action Allow -Protocol ICMPv4 -IcmpType 8 -LocalAddress 10.10.0.1 -RemoteAddress 10.10.0.2 -Profile Any
```

Inspect the rules:

```powershell
Get-NetFirewallRule -Name 'FreePN-WireGuard-LAN','FreePN-VPN-Ping' | Format-Table Name,Enabled,Profile,Direction,Action
Get-NetFirewallRule -Name 'FreePN-WireGuard-LAN' | Get-NetFirewallPortFilter
Get-NetFirewallRule -Name 'FreePN-WireGuard-LAN','FreePN-VPN-Ping' | Get-NetFirewallAddressFilter
```

Keep Windows Firewall enabled. Managed firewall policy can override local
rules. The parameter reference is [Microsoft's New-NetFirewallRule documentation](https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule).

## 5. Activate and verify the server

Save the server configuration and select **Activate** for `freepn-server`.
Leave `freepn-client-keys` inactive.

In administrator PowerShell:

```powershell
Get-NetIPAddress -InterfaceAlias 'freepn-server' -AddressFamily IPv4
& 'C:\Program Files\WireGuard\wg.exe' show freepn-server
Get-NetUDPEndpoint -LocalPort 51820 | Format-Table LocalAddress,LocalPort,OwningProcess
```

Expected results:

- The tunnel adapter has `10.10.0.1` with prefix length `24`.
- WireGuard reports listening port `51820` and a peer allowed IP of
  `10.10.0.2/32`.
- A UDP endpoint is bound to port `51820`. It may show a wildcard local
  address rather than the VPN address.

A UDP binding confirms a local socket exists, not that the phone can reach it.
Use both the WireGuard status and socket check. `Test-NetConnection -Port`
tests TCP, so it cannot validate this WireGuard UDP listener.
Microsoft documents the socket check in [Get-NetUDPEndpoint](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netudpendpoint).

Before the phone connects, an absent handshake is expected. Later, a recent
handshake and increasing transfer counters provide stronger evidence.
Ordinary `wg show freepn-server` hides the private key by default.
Do not share `showconf`, `dump`, or `private-key` output: those can expose
credentials. See [wg's command reference](https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8).

## 6. Prepare FreePN and record the Phase 7 checks

Run the Android app from this project's root:

```powershell
flutter run
```

Enter your recorded LAN endpoint. Under **Configure WireGuard keys**, enter the
client private key and server public key, then choose **Use keys**.

Phase 7 will verify these items on the real phone:

- Android's VPN permission is approved and FreePN activates the tunnel.
- The phone uses its configured static address `10.10.0.2/24` (no DHCP).
- Server status shows a recent handshake and traffic counters.
- A phone-side ping to `10.10.0.1` succeeds.
- Disconnect and reconnect both work.

FreePN's **Connected** status currently means the local Android tunnel is up.
The app has no built-in ping test yet. A laptop ping to its own `10.10.0.1`
does not prove that the phone is connected. Keep real-device reachability
marked unverified until Phase 7; internet routing is a later phase.

## Troubleshooting and stopping

| Symptom | Check |
| --- | --- |
| Cannot activate server | WireGuard GUI log, valid keys, and whether another process/tunnel owns UDP 51820 |
| Phone says Connected, no handshake | Actual LAN endpoint, same LAN, guest/client isolation, UDP rule profile/interface, and both public/private key mappings |
| Handshake exists, ping fails | Client/server addresses, server peer `10.10.0.2/32`, ping rule, and overlapping routes |
| Worked yesterday | Laptop DHCP address changed, laptop asleep, or different Wi-Fi/profile |
| Hostnames fail | Use numeric addresses for this local test; DNS is not the milestone |

To stop the server, select **Deactivate** in WireGuard. Closing its window is
not the same as deactivating the tunnel.

If retiring this test setup, disable only the rules created above:

```powershell
Disable-NetFirewallRule -Name 'FreePN-WireGuard-LAN','FreePN-VPN-Ping'
```

To resume later, use `Enable-NetFirewallRule` with those same rule names and
activate `freepn-server`. Keep your keys private and outside Git.
