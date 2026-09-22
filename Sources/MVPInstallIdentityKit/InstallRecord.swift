import Foundation

/// The record persisted in the Keychain. Intentionally tiny and anonymous:
/// a random identifier plus the date it was first created. No device
/// hardware identifiers (IDFV/IDFA/serial numbers etc.) are ever touched —
/// this library only ever asks "has *this* app's Keychain item been seen
/// before on this device", not "who is this physical device / user".
struct InstallRecord: Codable, Equatable {
    let id: UUID
    let firstSeenDate: Date
}

/// The result of resolving the install identity for the current launch.
public struct InstallInfo: Equatable {
    /// Stable, anonymous identifier for this app install. Regenerated only
    /// if the Keychain item is missing (e.g. genuinely new install, or the
    /// Keychain item was cleared).
    public let id: UUID

    /// When this identifier was first created — i.e. the first time
    /// `InstallIdentifier.resolve()` ever ran successfully on this device
    /// for this app/service, not necessarily the App Store install date.
    public let firstSeenDate: Date

    /// `true` if this call created a brand-new record (nothing was found in
    /// the Keychain beforehand). `false` if an existing record was read.
    ///
    /// Note the naming: this reflects "no matching Keychain item existed",
    /// which is usually but not always the same as "first-ever app launch"
    /// — see the README section on Keychain persistence caveats (backup
    /// restores, jailbreak tools, iOS version differences).
    public let isFirstLaunchEver: Bool
}
