# Phase 10: prepare IPv4 internet routing through the Windows laptop

## Current laptop limitation

The development laptop runs Windows 11 Home. The follow-up
`Get-CimClass -Namespace root/StandardCimv2 -ClassName MSFT_NetNat` check
returned `Not found`. The WinNAT procedure below is therefore **not available
on this laptop as currently configured**. Do not run its forwarding or
`New-NetNat` commands here. [Microsoft's NAT setup guide](https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/setup-nat-network)
requires Hyper-V, and [Microsoft states that the Hyper-V role cannot be
installed on Windows 11 Home](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/install-hyper-v?pivots=windows&tabs=gui).
The local VPN remains usable in its default mode. IPv4 internet routing needs
a supported gateway or a separately designed and validated alternative; do
not treat Windows Internet Connection Sharing as a drop-in replacement.

FreePN now has an opt-in **Route internet IPv4 through laptop** switch. It
changes the client peer's `AllowedIPs` from `10.10.0.0/24` to `0.0.0.0/0`.
The tested local mode remains the default. This switch does **not** configure
the Windows host, and the IPv4 internet path has not been verified on a phone.
Do not enable it until you have a working local handshake and have prepared
the laptop to forward and translate traffic.

This is **IPv4-only**, not a privacy-complete full tunnel. IPv6 is not routed
through FreePN and may use the phone's underlying network. Do not rely on this
mode for leak prevention or anonymity. The DNS server is `1.1.1.1`; when the
IPv4 default route is active, it also needs the laptop's forwarding/NAT path.
If that path fails, disconnect in FreePN and return to local mode.

## WinNAT laptop preparation (supported hosts only; not this Windows Home laptop)

Use only on a trusted network you administer. The Windows laptop becomes a
gateway for the phone. Record existing values before changing anything, and
do not delete or replace an existing NAT or disable Windows Firewall.

1. Confirm the existing Phase 7 local tunnel still works. Check the actual
   LAN interface alias and the two IPv4 interface forwarding states:

   ```powershell
   Get-NetIPConfiguration
   Get-NetIPInterface -AddressFamily IPv4 -InterfaceAlias 'freepn-server','Wi-Fi' | Select-Object InterfaceAlias,Forwarding
   Get-NetNat -ErrorAction Stop | Select-Object Name,InternalIPInterfaceAddressPrefix
   ```

   Replace `Wi-Fi` in this guide if your internet-facing interface has a
   different alias. Check that `10.10.0.0/24` does not overlap another active
   network. If an existing NAT is listed, **stop**: Windows NAT can conflict
   with another internal prefix. Do not remove Docker, WSL, Hyper-V, or other
   NAT objects just for this test. See [Microsoft's WinNAT guidance](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/setup-nat-network).

   On the development laptop (Windows 11 Home), read-only checks in a
   non-administrator shell found no `MSFT_NetNat` CIM class; `Get-NetNat`
   returned `Invalid class` in both PowerShell 7 and Windows PowerShell 5.1.
   That is **not** evidence that no NAT exists. In administrator PowerShell,
   repeat `Get-NetNat -ErrorAction Stop` and check the class with:

   ```powershell
   Get-CimClass -Namespace root/StandardCimv2 -ClassName MSFT_NetNat -ErrorAction Stop
   ```

   If either command errors, stop before changing forwarding or calling
   `New-NetNat`. The NAT provider or host support must be resolved separately;
   do not interpret an error as an empty NAT list. Do not enable Internet
   Connection Sharing as an automatic workaround: it provides its own address
   assignment on the private interface and may break this tunnel's static
   `10.10.0.1/24` setup. See [Microsoft's ICS description](https://learn.microsoft.com/en-us/windows/win32/nativewifi/using-hosted-network-and-internet-connection-sharing).

2. Only if both checks above succeed and there is no conflicting NAT, enable
   IPv4 forwarding on the WireGuard
   interface and internet-facing interface, then create one NAT for FreePN's
   VPN subnet:

   ```powershell
   Set-NetIPInterface -InterfaceAlias 'freepn-server' -AddressFamily IPv4 -Forwarding Enabled
   Set-NetIPInterface -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -Forwarding Enabled
   New-NetNat -Name 'FreePN-NAT' -InternalIPInterfaceAddressPrefix '10.10.0.0/24'
   ```

   These are laptop-wide networking changes. If a command fails, stop and
   inspect the error; do not add a second NAT. [Set-NetIPInterface](https://learn.microsoft.com/en-us/powershell/module/nettcpip/set-netipinterface)
   controls per-interface forwarding, and [New-NetNat](https://learn.microsoft.com/en-us/powershell/module/netnat/new-netnat)
   creates address translation. Neither command is run by the app.

3. Verify the resulting configuration without exposing keys:

   ```powershell
   Get-NetIPInterface -AddressFamily IPv4 -InterfaceAlias 'freepn-server','Wi-Fi' | Select-Object InterfaceAlias,Forwarding
   Get-NetNat -Name 'FreePN-NAT' | Select-Object Name,InternalIPInterfaceAddressPrefix
   & 'C:\Program Files\WireGuard\wg.exe' show freepn-server
   ```

   Keep the server peer's `AllowedIPs = 10.10.0.2/32`; only the **phone's**
   route changes to `0.0.0.0/0`. No router port forwarding is needed while
   phone and laptop remain on the same LAN. Keep the existing narrowly scoped
   WireGuard UDP firewall rule. Do not disable the firewall to diagnose a
   failure; inspect blocked traffic and add only a justified, narrow rule.

## Phone validation (not yet performed)

Disconnect FreePN, enable **Route internet IPv4 through laptop**, and connect
again with the known-good endpoint and keys. Confirm a fresh server handshake.
Then test both an external numeric IPv4 destination (for example `1.1.1.1`)
and a normal HTTPS website by name on the phone. Compare the server's peer
transfer counters before and after generating traffic. A displayed
**Connected** state or handshake alone does not prove forwarding, NAT, DNS,
or web traffic works. Record failures separately: handshake, external IPv4,
DNS, and HTTPS. Retest the original local mode afterward.

If the Windows host already has NAT/ICS, forwarding is blocked by policy, or
the phone cannot pass external traffic, leave the switch off and investigate
the host configuration before claiming Phase 10 complete. Do not share
private keys or full WireGuard configuration in test reports.

## Revert only FreePN's host changes

After testing, disconnect the phone first. If you created the NAT named
`FreePN-NAT`, remove only that object with `Remove-NetNat -Name 'FreePN-NAT'`.
Restore forwarding on each interface to the values you recorded above, using
`Set-NetIPInterface -InterfaceAlias <alias> -AddressFamily IPv4 -Forwarding
<original-value>`. Do not assume both original values were Disabled.
