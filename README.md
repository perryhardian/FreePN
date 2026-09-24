# FreePN

An Android-first Flutter starter for a local WireGuard VPN client.

## Current scope

- Phase 1: Flutter project structure
- Phase 2: Basic responsive connection UI
- Phase 3: `VpnService` abstraction backed by a Flutter method channel
- Phase 4: Android VPN permission flow and official WireGuard tunnel backend

The Android layer now requests VPN permission and can start or stop a tunnel
through the official WireGuard Android tunnel library. Phase 5 still needs to
supply a complete WireGuard configuration at runtime, so **Connect** currently
reports a missing-configuration error after permission is granted.

Do not place private keys or real WireGuard `.conf` files in this repository.

## Checks

Android builds require JDK 17 or newer.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```
