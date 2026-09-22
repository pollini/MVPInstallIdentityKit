# InstallIdentityKit

A tiny, dependency-free Swift package that answers one question reliably:

> **Has this app been installed on this device before — even if it was deleted and reinstalled in between?**

Useful when your app has no login/account system to key off of, and you still
need to tell apart a genuinely new user from someone reinstalling (e.g. to
avoid re-granting a one-time trial, or to avoid re-showing a first-launch
survey/paywall).

`UserDefaults` doesn't work for this — it's wiped on deletion. This library
persists a small, fully anonymous record in the **Keychain** instead, which
survives app deletion as long as the device itself isn't wiped.

```swift
import InstallIdentityKit

let info = try InstallIdentifier.shared.resolve()

if info.isFirstLaunchEver {
    // show onboarding, start a trial, etc.
}

print(info.id)            // UUID, stable across launches & reinstalls
print(info.firstSeenDate) // Date this identity was first created
```

## How it works

- On first successful call, a random `UUID` + the current `Date` are encoded
  to JSON and written to a `kSecClassGenericPassword` Keychain item with
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — accessible after the
  device's first unlock post-reboot, and explicitly **not** synced via iCloud
  Keychain to the user's other devices.
- Every later call reads that same item back instead of creating a new one.
- Deleting and reinstalling the app removes `UserDefaults` and app files, but
  the Keychain item is untouched (same Team ID + Bundle ID reinstall), so the
  next `resolve()` finds the existing record and reports
  `isFirstLaunchEver == false`.

The library only ever stores a value **it generated itself**. It never reads
`IDFA`, `IDFV`, serial numbers, or any other device/hardware identifier — see
[Privacy & App Store notes](#privacy--app-store-notes) below for why that
distinction matters.

## Architecture

```
InstallIdentifier          — public API, orchestrates read/create/persist
  └─ KeychainStoring        — protocol abstraction over "a secure key/value store"
       ├─ SystemKeychainStore — real Security.framework-backed implementation
       └─ InMemoryKeychainStore (test target) — fast, deterministic mock
```

Injecting `KeychainStoring` is what makes the whole thing unit-testable
without a real Keychain — which matters because the Keychain is flaky and
often unavailable in plain `swift test` runs (e.g. on Linux CI, or in a
simulator without a signed-in Apple ID). All of `InstallIdentifierTests.swift`
runs against `InMemoryKeychainStore` and covers first-launch detection,
persistence across independent instances, isolation between different
`service`/`account` pairs, `reset()`, error propagation, and concurrent
first-access thread-safety.

## Installation

Swift Package Manager, via Xcode: **File → Add Package Dependencies…** and
point it at this repository, or add it to `Package.swift`:

```swift
.package(url: "https://github.com/pollini/InstallIdentityKit.git", from: "1.0.0")
```

## Privacy & App Store notes

This pattern (persist an identifier in the Keychain so it survives
reinstall) is used by several install/analytics SDKs, but it sits close to a
line Apple cares about:

- If used to **defeat a legitimate "new install" experience for the user's
  benefit** (e.g. don't re-show onboarding, prevent trivial trial-abuse),
  this is a defensible, common use case.
- If used to **track/fingerprint a user across app reinstalls for
  advertising or cross-app tracking**, this falls under Apple's App Tracking
  Transparency (ATT) rules and App Store Review Guidelines — that use case
  requires ATT consent and is a materially different (and much more
  regulated) thing than "did this app run on this device before".

This library deliberately does **not** implement any tracking, networking,
or cross-app sharing — it's a local, opt-in-by-integration building block.
If you use it, document in your own app's privacy manifest / App Store
privacy labels what you use the identifier for, same as you would for any
other persisted identifier.

## Known limitations

- **Not guaranteed across all scenarios.** Keychain persistence across
  reinstall is best-effort: it can behave differently across iOS versions,
  and is affected by whether the device was restored from a backup or is the
  original device. Treat `isFirstLaunchEver == true` as "no evidence of a
  prior install", not as a legal/security guarantee.
- **Full device wipe / new device** always resets the identity — this is a
  per-device, not a per-user or per-iCloud-account identifier.
- `reset()` exists for debug/test flows only; calling it in a shipped code
  path defeats the entire purpose of the library.

## License

MIT, see [LICENSE](LICENSE).
