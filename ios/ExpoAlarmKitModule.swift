import ExpoModulesCore
import AlarmKit
import ActivityKit
import AppIntents
import SwiftUI
import UIKit

// MARK: - Storage Keys
private let alarmKeyPrefix = "ExpoAlarmKit.alarm:"
private let launchAppKeyPrefix = "ExpoAlarmKit.launchApp:"
private let rescheduleConfigKeyPrefix = "ExpoAlarmKit.rescheduleConfig:"
private let rescheduledKeyPrefix = "ExpoAlarmKit.rescheduled:"
// alarmId -> id of the next backstop rung armed behind it. See armBackstopAlarm.
private let backstopKeyPrefix = "ExpoAlarmKit.backstop:"

/// Ceiling on the alarms armed for a single fire event: the alarm itself plus
/// the backstop ladder behind it.
private let maxAlarmsPerChain = 8

// MARK: - App Group Storage Manager
@available(iOS 26.0, *)
public class ExpoAlarmKitStorage {
    public static var appGroupIdentifier: String? = nil
    
    public static var sharedDefaults: UserDefaults? {
        guard let groupId = appGroupIdentifier else {
            print("[ExpoAlarmKit] Warning: App Group not configured. Call configure() first.")
            return nil
        }
        return UserDefaults(suiteName: groupId)
    }
    
    public static func setAlarm(id: String, value: Double) {
        sharedDefaults?.set(value, forKey: alarmKeyPrefix + id)
    }
    
    public static func removeAlarm(id: String) {
        sharedDefaults?.removeObject(forKey: alarmKeyPrefix + id)
    }
    
    public static func getAllAlarmIds() -> [String] {
        guard let defaults = sharedDefaults?.dictionaryRepresentation() else { return [] }
        var alarmIds: [String] = []
        for key in defaults.keys {
            if key.hasPrefix(alarmKeyPrefix) {
                let alarmId = String(key.dropFirst(alarmKeyPrefix.count))
                alarmIds.append(alarmId)
            }
        }
        return alarmIds
    }

    /// Same keys as `getAllAlarmIds`, but keeps the stored fire time instead of
    /// discarding it. `fireEpoch` is the scheduled fire time in Unix seconds;
    /// -2 marks a timer, and -1 a repeating alarm scheduled before this stored
    /// a real date (older installs).
    public static func getAllAlarmEntries() -> [(id: String, fireEpoch: Double)] {
        guard let defaults = sharedDefaults?.dictionaryRepresentation() else { return [] }
        var entries: [(String, Double)] = []
        for (key, value) in defaults {
            if key.hasPrefix(alarmKeyPrefix), let epoch = value as? Double {
                entries.append((String(key.dropFirst(alarmKeyPrefix.count)), epoch))
            }
        }
        return entries
    }
    
    public static func clearAllAlarms() {
        guard let defaults = sharedDefaults?.dictionaryRepresentation() else { return }
        for key in defaults.keys {
            if key.hasPrefix(alarmKeyPrefix) {
                sharedDefaults?.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Reschedule Config Storage
    public static func setRescheduleConfig(alarmId: String, config: PersistentAlarmConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        sharedDefaults?.set(data, forKey: rescheduleConfigKeyPrefix + alarmId)
    }

    public static func getRescheduleConfig(alarmId: String) -> PersistentAlarmConfig? {
        guard let data = sharedDefaults?.data(forKey: rescheduleConfigKeyPrefix + alarmId) else { return nil }
        return try? JSONDecoder().decode(PersistentAlarmConfig.self, from: data)
    }

    public static func removeRescheduleConfig(alarmId: String) {
        sharedDefaults?.removeObject(forKey: rescheduleConfigKeyPrefix + alarmId)
    }

    // MARK: - Pending Reschedule Mappings (originalId -> newId, readable by JS)
    public static func setRescheduled(originalAlarmId: String, newAlarmId: String) {
        sharedDefaults?.set(newAlarmId, forKey: rescheduledKeyPrefix + originalAlarmId)
    }

    public static func getAllRescheduled() -> [(originalAlarmId: String, newAlarmId: String)] {
        guard let defaults = sharedDefaults?.dictionaryRepresentation() else { return [] }
        var result: [(String, String)] = []
        for (key, value) in defaults {
            if key.hasPrefix(rescheduledKeyPrefix), let newId = value as? String {
                let originalId = String(key.dropFirst(rescheduledKeyPrefix.count))
                result.append((originalId, newId))
            }
        }
        return result
    }

    public static func clearAllRescheduled() {
        guard let defaults = sharedDefaults?.dictionaryRepresentation() else { return }
        for key in defaults.keys {
            if key.hasPrefix(rescheduledKeyPrefix) {
                sharedDefaults?.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Backstop Mappings (alarmId -> the backstop armed for it)
    public static func setBackstop(alarmId: String, backstopId: String) {
        sharedDefaults?.set(backstopId, forKey: backstopKeyPrefix + alarmId)
    }

    public static func getBackstopId(alarmId: String) -> String? {
        return sharedDefaults?.string(forKey: backstopKeyPrefix + alarmId)
    }

    public static func removeBackstop(alarmId: String) {
        sharedDefaults?.removeObject(forKey: backstopKeyPrefix + alarmId)
    }

    /// Every armed backstop id. JS needs these to keep its orphan sweep from
    /// cancelling the safety net — backstops deliberately live outside the
    /// app's alarms table.
    public static func getAllBackstopIds() -> [String] {
        guard let defaults = sharedDefaults?.dictionaryRepresentation() else { return [] }
        var ids: [String] = []
        for (key, value) in defaults {
            if key.hasPrefix(backstopKeyPrefix), let id = value as? String {
                ids.append(id)
            }
        }
        return ids
    }

    public static func setLaunchAppOnDismiss(alarmId: String, value: Bool) {
        sharedDefaults?.set(value, forKey: launchAppKeyPrefix + alarmId)
    }
    
    public static func getLaunchAppOnDismiss(alarmId: String) -> Bool {
        return sharedDefaults?.bool(forKey: launchAppKeyPrefix + alarmId) ?? false
    }
    
    public static func removeLaunchAppOnDismiss(alarmId: String) {
        sharedDefaults?.removeObject(forKey: launchAppKeyPrefix + alarmId)
    }
}

// MARK: - Record Structs for Expo Module
@available(iOS 26.0, *)
struct ScheduleAlarmOptions: Record {
    @Field var id: String
    @Field var epochSeconds: Double
    @Field var title: String
    @Field var soundName: String?
    @Field var launchAppOnDismiss: Bool?
    @Field var doSnoozeIntent: Bool?
    @Field var launchAppOnSnooze: Bool?
    @Field var dismissPayload: String?
    @Field var snoozePayload: String?
    @Field var stopButtonLabel: String?
    @Field var snoozeButtonLabel: String?
    @Field var stopButtonColor: String?
    @Field var snoozeButtonColor: String?
    @Field var tintColor: String?
    @Field var snoozeDuration: Int?
    /// When set, dismissing the alarm without opening the app will automatically
    /// reschedule it this many seconds later. No app launch required.
    @Field var rescheduleDelaySeconds: Double?
    /// When set, a one-time backstop alarm is armed this many seconds after
    /// this alarm's own fire time, at schedule time rather than at dismiss
    /// time. It fires unless a successful dismiss cancels it.
    @Field var backstopDelaySeconds: Double?
}

@available(iOS 26.0, *)
struct ScheduleRepeatingAlarmOptions: Record {
    @Field var id: String
    @Field var hour: Int
    @Field var minute: Int
    @Field var weekdays: [Int]
    @Field var title: String
    @Field var soundName: String?
    @Field var launchAppOnDismiss: Bool?
    @Field var doSnoozeIntent: Bool?
    @Field var launchAppOnSnooze: Bool?
    @Field var dismissPayload: String?
    @Field var snoozePayload: String?
    @Field var stopButtonLabel: String?
    @Field var snoozeButtonLabel: String?
    @Field var stopButtonColor: String?
    @Field var snoozeButtonColor: String?
    @Field var tintColor: String?
    @Field var snoozeDuration: Int?
    /// When set, a one-time backstop alarm is armed this many seconds after
    /// this alarm's next fire time. See ScheduleAlarmOptions.backstopDelaySeconds.
    @Field var backstopDelaySeconds: Double?
    /// When set, dismissing without opening the app reschedules a one-time alarm
    /// this many seconds later. Repeats until the user opens the app and cancels.
    @Field var rescheduleDelaySeconds: Double?
}

@available(iOS 26.0, *)
struct ScheduleTimerOptions: Record {
    @Field var id: String
    @Field var duration: Double
    @Field var title: String
    @Field var soundName: String?
    @Field var tintColor: String?
    @Field var pauseButtonLabel: String?
    @Field var pauseButtonColor: String?
    @Field var resumeButtonLabel: String?
    @Field var resumeButtonColor: String?
    @Field var launchAppOnDismiss: Bool?
    @Field var dismissPayload: String?
}

// MARK: - Helper Functions
private func colorFromHex(_ hex: String) -> Color {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
    
    var rgb: UInt64 = 0
    Scanner(string: hexSanitized).scanHexInt64(&rgb)
    
    let r = Double((rgb & 0xFF0000) >> 16) / 255.0
    let g = Double((rgb & 0x00FF00) >> 8) / 255.0
    let b = Double(rgb & 0x0000FF) / 255.0
    
    return Color(red: r, green: g, blue: b)
}

private func buildLaunchPayload(alarmId: String, payload: String?) -> [String: Any] {
    return [
        "alarmId": alarmId,
        "payload": payload ?? NSNull()
    ]
}

// MARK: - App Intent for Alarm Dismissal (No App Launch)
@available(iOS 26.0, *)
public struct AlarmDismissIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Dismiss Alarm"
    public static var description = IntentDescription("Handles alarm dismissal")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "alarmId")
    public var alarmId: String

    @Parameter(title: "payload")
    public var payload: String?

    // Carried so the background process can access App Group storage without the app running
    @Parameter(title: "appGroupIdentifier")
    public var appGroupIdentifier: String

    public init() { self.appGroupIdentifier = "" }

    public init(alarmId: String, payload: String? = nil, appGroupIdentifier: String) {
        self.alarmId = alarmId
        self.payload = payload
        self.appGroupIdentifier = appGroupIdentifier
    }

    public func perform() async throws -> some IntentResult {
        // Bootstrap storage so this background process can read/write App Group defaults
        ExpoAlarmKitStorage.appGroupIdentifier = self.appGroupIdentifier

        // No reschedule config means this alarm was never part of a chain, so
        // there is nothing to keep alive and teardown is unconditional.
        var successorArmed = true
        if let config = ExpoAlarmKitStorage.getRescheduleConfig(alarmId: self.alarmId) {
            successorArmed = await rescheduleAlarmInBackground(config: config)
        }

        // Tearing this down is only safe once a successor is actually armed.
        // Deleting the config after a failed reschedule leaves nothing to
        // recover from: no alarm, no mapping, no config — the chain is gone for
        // good and the user sleeps through. Keep it, leave the backstop armed,
        // and let that carry the chain instead.
        if successorArmed {
            cancelBackstopChain(for: self.alarmId)
            ExpoAlarmKitStorage.removeAlarm(id: self.alarmId)
            ExpoAlarmKitStorage.removeLaunchAppOnDismiss(alarmId: self.alarmId)
            ExpoAlarmKitStorage.removeRescheduleConfig(alarmId: self.alarmId)
        }

        return .result()
    }
}

@available(iOS 26.0, *)
public struct PersistentAlarmConfig: Codable {
    let originalAlarmId: String
    let title: String
    let soundName: String?
    let rescheduleDelaySeconds: Double
    /// nil disables the backstop. Optional so configs written by older builds
    /// still decode.
    let backstopDelaySeconds: Double?
    let stopButtonLabel: String?
    let stopButtonColor: String?
    let snoozeButtonLabel: String?
    let snoozeButtonColor: String?
    let tintColor: String?
    let snoozeDuration: Int?
    let doSnoozeIntent: Bool
    let launchAppOnSnooze: Bool
    let snoozePayload: String?
    let dismissPayload: String?
    let launchAppOnDismiss: Bool
}

/// Next occurrence of a weekly recurrence, so repeating alarms can store a real
/// fire time instead of a sentinel. Weekdays are 1=Sunday...7=Saturday, matching
/// both the JS side and Calendar's `.weekday` component.
@available(iOS 26.0, *)
private func nextFireDate(hour: Int, minute: Int, weekdays: [Int], from now: Date = Date()) -> Date? {
    let calendar = Calendar.current
    // 0...7 rather than 0...6: today may already be past the time, so the same
    // weekday one week out is a legitimate answer.
    for dayOffset in 0...7 {
        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
        let weekday = calendar.component(.weekday, from: day)
        guard weekdays.isEmpty || weekdays.contains(weekday) else { continue }
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        guard let fire = calendar.date(from: comps) else { continue }
        if fire > now { return fire }
    }
    return nil
}

/// Every alarm in a reschedule chain — successors and backstops alike — is
/// presented identically, so it is built in one place.
///
/// No snooze button. `.countdown` snoozes natively without running any intent,
/// so the app never learns the alarm fired — no mapping, no challenge. Stop is
/// the only exit, and Stop always runs AlarmDismissIntent. AlarmKit always
/// renders a secondary button and it can't be removed, so it is wired to the
/// same dismiss intent as Stop: `.custom` runs our intent instead of AlarmKit's
/// native countdown, so whichever button the user taps the alarm reschedules
/// and a mapping is written.
@available(iOS 26.0, *)
struct ChainAlarmMeta: AlarmMetadata {}

@available(iOS 26.0, *)
private func buildChainAlarmConfiguration(
    config: PersistentAlarmConfig,
    alarmId: String,
    fireDate: Date
) -> AlarmManager.AlarmConfiguration<ChainAlarmMeta> {
    let stopLabel = config.stopButtonLabel ?? "Stop"
    let stopColor = config.stopButtonColor != nil ? colorFromHex(config.stopButtonColor!) : Color.white
    let stopButton = AlarmButton(
        text: LocalizedStringResource(stringLiteral: stopLabel),
        textColor: stopColor,
        systemImageName: "stop.circle"
    )

    let snoozeLabel = config.snoozeButtonLabel ?? "Snooze"
    let snoozeColor = config.snoozeButtonColor != nil ? colorFromHex(config.snoozeButtonColor!) : Color.white
    let snoozeButton = AlarmButton(
        text: LocalizedStringResource(stringLiteral: snoozeLabel),
        textColor: snoozeColor,
        systemImageName: "stop.circle"
    )

    let alertPresentation = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: config.title),
        stopButton: stopButton,
        secondaryButton: snoozeButton,
        secondaryButtonBehavior: .custom
    )

    let countdownDuration = Alarm.CountdownDuration(
        preAlert: nil,
        postAlert: TimeInterval(config.snoozeDuration ?? (9 * 60))
    )

    let alarmTintColor = config.tintColor != nil ? colorFromHex(config.tintColor!) : Color.blue
    let attributes = AlarmAttributes<ChainAlarmMeta>(
        presentation: AlarmPresentation(alert: alertPresentation),
        metadata: ChainAlarmMeta(),
        tintColor: alarmTintColor
    )

    let alarmSound: AlertConfiguration.AlertSound
    if let soundName = config.soundName, !soundName.isEmpty {
        alarmSound = .named(soundName)
    } else {
        alarmSound = .default
    }

    let appGroupId = ExpoAlarmKitStorage.appGroupIdentifier ?? ""
    let stopIntent: any LiveActivityIntent = config.launchAppOnDismiss
        ? AlarmDismissIntentWithLaunch(alarmId: alarmId, payload: config.dismissPayload, appGroupIdentifier: appGroupId)
        : AlarmDismissIntent(alarmId: alarmId, payload: config.dismissPayload, appGroupIdentifier: appGroupId)

    // Same intent as Stop — snooze must not be a way out of the challenge.
    let secondaryIntent: (any LiveActivityIntent)? = config.launchAppOnDismiss
        ? AlarmDismissIntentWithLaunch(alarmId: alarmId, payload: config.dismissPayload, appGroupIdentifier: appGroupId)
        : AlarmDismissIntent(alarmId: alarmId, payload: config.dismissPayload, appGroupIdentifier: appGroupId)

    return AlarmManager.AlarmConfiguration<ChainAlarmMeta>(
        countdownDuration: countdownDuration,
        schedule: .fixed(fireDate),
        attributes: attributes,
        stopIntent: stopIntent,
        secondaryIntent: secondaryIntent,
        sound: alarmSound
    )
}

/// Copy of `config` re-pointed at the chain root, for the next hop.
@available(iOS 26.0, *)
private func successorConfig(from config: PersistentAlarmConfig) -> PersistentAlarmConfig {
    return PersistentAlarmConfig(
        // Carry the ROOT id, not this hop's id. This field identifies the alarm
        // the user actually created; overwriting it each hop turns the pending
        // mappings into a chain JS has to walk in order.
        originalAlarmId: config.originalAlarmId,
        title: config.title,
        soundName: config.soundName,
        rescheduleDelaySeconds: config.rescheduleDelaySeconds,
        backstopDelaySeconds: config.backstopDelaySeconds,
        stopButtonLabel: config.stopButtonLabel,
        stopButtonColor: config.stopButtonColor,
        snoozeButtonLabel: config.snoozeButtonLabel,
        snoozeButtonColor: config.snoozeButtonColor,
        tintColor: config.tintColor,
        snoozeDuration: config.snoozeDuration,
        doSnoozeIntent: config.doSnoozeIntent,
        launchAppOnSnooze: config.launchAppOnSnooze,
        snoozePayload: config.snoozePayload,
        dismissPayload: config.dismissPayload,
        launchAppOnDismiss: config.launchAppOnDismiss
    )
}

/// Cancels one backstop alarm and forgets everything stored about it.
@available(iOS 26.0, *)
private func cancelBackstopAlarm(_ backstopId: String) {
    if let uuid = UUID(uuidString: backstopId) {
        try? AlarmManager.shared.cancel(id: uuid)
    }
    ExpoAlarmKitStorage.removeAlarm(id: backstopId)
    ExpoAlarmKitStorage.removeRescheduleConfig(alarmId: backstopId)
    ExpoAlarmKitStorage.removeLaunchAppOnDismiss(alarmId: backstopId)
}

/// Cancels the backstop armed for `alarmId`, and any backstop armed for that
/// backstop in turn. A backstop is a full chain member, so it can have grown a
/// net of its own before this runs.
@available(iOS 26.0, *)
private func cancelBackstopChain(for alarmId: String) {
    var current = alarmId
    var seen: Set<String> = [alarmId]
    while let backstopId = ExpoAlarmKitStorage.getBackstopId(alarmId: current) {
        ExpoAlarmKitStorage.removeBackstop(alarmId: current)
        if seen.contains(backstopId) { break }
        seen.insert(backstopId)
        cancelBackstopAlarm(backstopId)
        current = backstopId
    }
}

/// Arms the safety net for `alarmId`: a ladder of one-time alarms at
/// `backstopDelaySeconds` intervals past that alarm's own fire time, each of
/// which goes off unless a successful dismiss cancels it first.
///
/// The point is *when* this is armed. The dismiss-time reschedule runs from a
/// background App Intent that AlarmKit can refuse — most reliably when the
/// device is sitting on the lock screen with the passcode prompt up — and when
/// it is refused there is nothing left to wake the user. These are armed
/// earlier, from a context that could already schedule, so they survive that
/// window. Each rung is a full chain member: dismissing it reschedules and
/// arms the next backstop, so the net never runs out.
///
/// The ladder is what survives a *silence* that is not a dismiss — the Ring/
/// Silent switch, a volume button or the side button all quiet a ringing alarm
/// without dismissing it, which leaves the dismiss-driven reschedule unfired.
/// One rung per silence, so sleeping through costs a deliberate act each time.
///
/// Rungs are stored as a linked list off `alarmId`, so `cancelBackstopChain`
/// tears down the whole ladder, and dismissing any rung takes the later ones
/// with it.
@available(iOS 26.0, *)
private func armBackstopAlarm(for alarmId: String, config: PersistentAlarmConfig, baseFireDate: Date) async {
    guard let delay = config.backstopDelaySeconds, delay > 0 else { return }

    // Replace whatever is already armed for this alarm rather than stacking.
    cancelBackstopChain(for: alarmId)

    let backstopConfig = successorConfig(from: config)
    var previousId = alarmId

    for rung in 1..<maxAlarmsPerChain {
        let offset = delay * Double(rung)
        let candidate = baseFireDate.addingTimeInterval(offset)
        let fireDate = candidate > Date() ? candidate : Date().addingTimeInterval(offset)

        let backstopId = UUID()
        let backstopIdString = backstopId.uuidString

        do {
            try await AlarmManager.shared.schedule(
                id: backstopId,
                configuration: buildChainAlarmConfiguration(
                    config: backstopConfig,
                    alarmId: backstopIdString,
                    fireDate: fireDate
                )
            )
        } catch {
            // Keep the rungs armed so far: a short ladder beats no ladder.
            print("[ExpoAlarmKit] Failed to arm backstop rung \(rung) for \(alarmId): \(error)")
            return
        }

        ExpoAlarmKitStorage.setAlarm(id: backstopIdString, value: fireDate.timeIntervalSince1970)
        ExpoAlarmKitStorage.setRescheduleConfig(alarmId: backstopIdString, config: backstopConfig)
        ExpoAlarmKitStorage.setBackstop(alarmId: previousId, backstopId: backstopIdString)
        previousId = backstopIdString
    }
}

/// Schedules the next alarm in the chain from within an AppIntent perform() —
/// runs without opening the app.
///
/// Returns whether a successor is actually armed. The caller MUST NOT tear down
/// the dismissed alarm's stored state on a false: that state, plus the backstop
/// armed earlier, is the only way the chain recovers.
@available(iOS 26.0, *)
private func rescheduleAlarmInBackground(config: PersistentAlarmConfig) async -> Bool {
    // A refusal here is sometimes transient, so it is worth a couple of quick
    // retries before falling back on the backstop.
    let backoffNanoseconds: [UInt64] = [0, 400_000_000, 1_200_000_000]

    for backoff in backoffNanoseconds {
        if backoff > 0 { try? await Task.sleep(nanoseconds: backoff) }

        let newAlarmId = UUID()
        let newAlarmIdString = newAlarmId.uuidString
        let fireDate = Date().addingTimeInterval(config.rescheduleDelaySeconds)
        let nextConfig = successorConfig(from: config)

        do {
            try await AlarmManager.shared.schedule(
                id: newAlarmId,
                configuration: buildChainAlarmConfiguration(
                    config: nextConfig,
                    alarmId: newAlarmIdString,
                    fireDate: fireDate
                )
            )
        } catch {
            print("[ExpoAlarmKit] Background reschedule failed: \(error)")
            continue
        }

        ExpoAlarmKitStorage.setAlarm(id: newAlarmIdString, value: fireDate.timeIntervalSince1970)
        // Carry the reschedule config forward so the next dismiss also reschedules
        ExpoAlarmKitStorage.setRescheduleConfig(alarmId: newAlarmIdString, config: nextConfig)
        // Record mapping so JS can reconcile alarm IDs when it next opens
        ExpoAlarmKitStorage.setRescheduled(originalAlarmId: config.originalAlarmId, newAlarmId: newAlarmIdString)
        await armBackstopAlarm(for: newAlarmIdString, config: nextConfig, baseFireDate: fireDate)
        return true
    }

    return false
}

// MARK: - App Intent for Alarm Dismissal (With App Launch)
@available(iOS 26.0, *)
public struct AlarmDismissIntentWithLaunch: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Dismiss Alarm"
    public static var description = IntentDescription("Handles alarm dismissal and opens app")
    // Starts in the background and only asks for the foreground once the chain
    // is safe. `openAppWhenRun` launched the app before perform() ran, so on a
    // locked device the passcode prompt came first and the reschedule was
    // refused while it was up.
    public static var supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "alarmId")
    public var alarmId: String

    @Parameter(title: "payload")
    public var payload: String?

    @Parameter(title: "appGroupIdentifier")
    public var appGroupIdentifier: String

    public init() { self.appGroupIdentifier = "" }

    public init(alarmId: String, payload: String? = nil, appGroupIdentifier: String) {
        self.alarmId = alarmId
        self.payload = payload
        self.appGroupIdentifier = appGroupIdentifier
    }

    public func perform() async throws -> some IntentResult {
        ExpoAlarmKitStorage.appGroupIdentifier = self.appGroupIdentifier
        ExpoAlarmKitModule.launchPayload = buildLaunchPayload(alarmId: self.alarmId, payload: self.payload)
        NSLog("[ExpoAlarmKit] launch-dismiss start alarm=%@ mode=%@", self.alarmId, String(describing: systemContext.currentMode))

        // No reschedule config means this alarm was never part of a chain, so
        // there is nothing to keep alive and teardown is unconditional.
        var successorArmed = true
        if let config = ExpoAlarmKitStorage.getRescheduleConfig(alarmId: self.alarmId) {
            successorArmed = await rescheduleAlarmInBackground(config: config)
        }

        // Tearing this down is only safe once a successor is actually armed.
        // Deleting the config after a failed reschedule leaves nothing to
        // recover from: no alarm, no mapping, no config — the chain is gone for
        // good and the user sleeps through. Keep it, leave the backstop armed,
        // and let that carry the chain instead.
        if successorArmed {
            cancelBackstopChain(for: self.alarmId)
            ExpoAlarmKitStorage.removeAlarm(id: self.alarmId)
            ExpoAlarmKitStorage.removeLaunchAppOnDismiss(alarmId: self.alarmId)
            ExpoAlarmKitStorage.removeRescheduleConfig(alarmId: self.alarmId)
        }

        // Only open the app on an already unlocked phone. On a locked phone the
        // foreground request puts up the passcode prompt, and while it is up
        // AlarmKit refuses to arm the next rung, so a user who leaves the phone
        // there exhausts the backstop ladder and the chain dies.
        let deviceUnlocked = await MainActor.run {
            UIApplication.shared.isProtectedDataAvailable
        }
        NSLog("[ExpoAlarmKit] launch-dismiss successorArmed=%@ unlocked=%@ canContinue=%@", successorArmed ? "yes" : "no", deviceUnlocked ? "yes" : "no", systemContext.currentMode.canContinueInForeground ? "yes" : "no")
        if !deviceUnlocked {
            NSLog("[ExpoAlarmKit] launch-dismiss phone locked, leaving app closed")
        } else if systemContext.currentMode.canContinueInForeground {
            do {
                try await continueInForeground(nil, alwaysConfirm: false)
                NSLog("[ExpoAlarmKit] launch-dismiss opened app")
            } catch {
                NSLog("[ExpoAlarmKit] launch-dismiss declined: %@", String(describing: error))
            }
        } else {
            NSLog("[ExpoAlarmKit] launch-dismiss cannot open app from this mode")
        }

        return .result()
    }
}

// MARK: - App Intent for Alarm Snooze (No App Launch)
@available(iOS 26.0, *)
public struct AlarmSnoozeIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Snooze Alarm"
    public static var description = IntentDescription("Handles alarm snooze")
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "alarmId")
    public var alarmId: String
    
    @Parameter(title: "payload")
    public var payload: String?
    
    public init() {}
    
    public init(alarmId: String, payload: String? = nil) {
        self.alarmId = alarmId
        self.payload = payload
    }
    
    public func perform() async throws -> some IntentResult {
        ExpoAlarmKitModule.launchPayload = buildLaunchPayload(alarmId: self.alarmId, payload: self.payload)
        return .result()
    }
}

// MARK: - App Intent for Alarm Snooze (With App Launch)
@available(iOS 26.0, *)
public struct AlarmSnoozeIntentWithLaunch: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Snooze Alarm"
    public static var description = IntentDescription("Handles alarm snooze and opens app")
    public static var openAppWhenRun: Bool = true
    
    @Parameter(title: "alarmId")
    public var alarmId: String
    
    @Parameter(title: "payload")
    public var payload: String?
    
    public init() {}
    
    public init(alarmId: String, payload: String? = nil) {
        self.alarmId = alarmId
        self.payload = payload
    }
    
    public func perform() async throws -> some IntentResult {
        ExpoAlarmKitModule.launchPayload = buildLaunchPayload(alarmId: self.alarmId, payload: self.payload)
        return .result()
    }
}

// MARK: - Expo Module
@available(iOS 26.0, *)
public class ExpoAlarmKitModule: Module {
    // Static payload for app launch detection
    public static var launchPayload: [String: Any]? = nil
    
    public func definition() -> ModuleDefinition {
        Name("ExpoAlarmKit")
        
        // MARK: - Configure App Group
        Function("configure") { (appGroupIdentifier: String) -> Bool in
            ExpoAlarmKitStorage.appGroupIdentifier = appGroupIdentifier
            // Verify the app group is accessible
            if ExpoAlarmKitStorage.sharedDefaults != nil {
                print("[ExpoAlarmKit] Configured with App Group: \(appGroupIdentifier)")
                return true
            } else {
                print("[ExpoAlarmKit] Failed to configure App Group: \(appGroupIdentifier)")
                return false
            }
        }
        
        // MARK: - Request Authorization
        AsyncFunction("requestAuthorization") { () -> String in
            let status = AlarmManager.shared.authorizationState
            switch status {
            case .authorized:
                return "authorized"
            case .denied:
                do {
                    let newStatus = try await AlarmManager.shared.requestAuthorization()
                    switch newStatus {
                    case .authorized:
                        return "authorized"
                    case .denied:
                        return "denied"
                    case .notDetermined:
                        return "notDetermined"
                    @unknown default:
                        return "notDetermined"
                    }
                } catch {
                    return "denied"
                }
            case .notDetermined:
                do {
                    let newStatus = try await AlarmManager.shared.requestAuthorization()
                    switch newStatus {
                    case .authorized:
                        return "authorized"
                    case .denied:
                        return "denied"
                    case .notDetermined:
                        return "notDetermined"
                    @unknown default:
                        return "notDetermined"
                    }
                } catch {
                    return "denied"
                }
            @unknown default:
                return "notDetermined"
            }
        }
        
        // MARK: - Generate UUID
        Function("generateUUID") { () -> String in
            return UUID().uuidString
        }
        
        // MARK: - Schedule One-Time Alarm
        AsyncFunction("scheduleAlarm") { (options: ScheduleAlarmOptions) async throws -> Bool in
            struct Meta: AlarmMetadata {}
            
            let date = Date(timeIntervalSince1970: options.epochSeconds)
            guard let uuid = UUID(uuidString: options.id) else {
                print("[ExpoAlarmKit] Invalid UUID string: \(options.id)")
                return false
            }
            let launchAppOnDismiss = options.launchAppOnDismiss ?? false
            
            // Create stop button
            let stopLabel = options.stopButtonLabel ?? "Stop"
            let stopColor = options.stopButtonColor != nil ? colorFromHex(options.stopButtonColor!) : Color.white
            let stopButton = AlarmButton(
                text: LocalizedStringResource(stringLiteral: stopLabel),
                textColor: stopColor,
                systemImageName: "stop.circle"
            )
            
            // No snooze button — see the note in rescheduleAlarmInBackground.
            let snoozeLabel = options.snoozeButtonLabel ?? "Snooze"
            let snoozeColor = options.snoozeButtonColor != nil ? colorFromHex(options.snoozeButtonColor!) : Color.white
            let snoozeButton = AlarmButton(
                text: LocalizedStringResource(stringLiteral: snoozeLabel),
                textColor: snoozeColor,
                systemImageName: "stop.circle"
            )

            // AlarmKit always renders a secondary button, so it can't be removed.
    // Wire it to the same dismiss intent as Stop: `.custom` runs our intent
    // instead of AlarmKit's native countdown, so whichever button the user taps
    // the alarm reschedules and a mapping is written.
            let alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: options.title),
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .custom
            )
            
            let presentation = AlarmPresentation(alert: alertPresentation)
            
            // Create countdown duration for snooze
            let countdownDuration = Alarm.CountdownDuration(
                preAlert: nil,
                postAlert: TimeInterval(options.snoozeDuration ?? (9 * 60))
            )
            
            // Create attributes
            let alarmTintColor = options.tintColor != nil ? colorFromHex(options.tintColor!) : Color.blue
            let attributes = AlarmAttributes<Meta>(
                presentation: presentation,
                metadata: Meta(),
                tintColor: alarmTintColor
            )
            
            // Determine sound
            let alarmSound: AlertConfiguration.AlertSound
            if let soundName = options.soundName, !soundName.isEmpty {
                alarmSound = .named(soundName)
            } else {
                alarmSound = .default
            }
            
            let appGroupId = ExpoAlarmKitStorage.appGroupIdentifier ?? ""
            let stopIntent: any LiveActivityIntent = launchAppOnDismiss
                ? AlarmDismissIntentWithLaunch(alarmId: options.id, payload: options.dismissPayload, appGroupIdentifier: appGroupId)
                : AlarmDismissIntent(alarmId: options.id, payload: options.dismissPayload, appGroupIdentifier: appGroupId)

            // Same intent as Stop — snooze must not be a way out of the challenge.
            let secondaryIntent: (any LiveActivityIntent)? = launchAppOnDismiss
                ? AlarmDismissIntentWithLaunch(alarmId: options.id, payload: options.dismissPayload, appGroupIdentifier: appGroupId)
                : AlarmDismissIntent(alarmId: options.id, payload: options.dismissPayload, appGroupIdentifier: appGroupId)

            // Create configuration
            let config = AlarmManager.AlarmConfiguration<Meta>(
                countdownDuration: countdownDuration,
                schedule: .fixed(date),
                attributes: attributes,
                stopIntent: stopIntent,
                secondaryIntent: secondaryIntent,
                sound: alarmSound
            )
            
            do {
                try await AlarmManager.shared.schedule(id: uuid, configuration: config)
                ExpoAlarmKitStorage.setAlarm(id: options.id, value: options.epochSeconds)
                // Store reschedule config in App Group so the dismiss intent can act without opening the app
                if let delay = options.rescheduleDelaySeconds {
                    let rescheduleConfig = PersistentAlarmConfig(
                        originalAlarmId: options.id,
                        title: options.title,
                        soundName: options.soundName,
                        rescheduleDelaySeconds: delay,
                        backstopDelaySeconds: options.backstopDelaySeconds,
                        stopButtonLabel: options.stopButtonLabel,
                        stopButtonColor: options.stopButtonColor,
                        snoozeButtonLabel: options.snoozeButtonLabel,
                        snoozeButtonColor: options.snoozeButtonColor,
                        tintColor: options.tintColor,
                        snoozeDuration: options.snoozeDuration,
                        doSnoozeIntent: options.doSnoozeIntent ?? false,
                        launchAppOnSnooze: options.launchAppOnSnooze ?? false,
                        snoozePayload: options.snoozePayload,
                        dismissPayload: options.dismissPayload,
                        launchAppOnDismiss: options.launchAppOnDismiss ?? false
                    )
                    ExpoAlarmKitStorage.setRescheduleConfig(alarmId: options.id, config: rescheduleConfig)
                    // Armed here, while scheduling demonstrably works, rather
                    // than at dismiss time when it may not.
                    await armBackstopAlarm(for: options.id, config: rescheduleConfig, baseFireDate: date)
                }
                return true
            } catch {
                print("[ExpoAlarmKit] Failed to schedule alarm: \(error)")
                return false
            }
        }

        // MARK: - Schedule Repeating Alarm
        AsyncFunction("scheduleRepeatingAlarm") { ( options: ScheduleRepeatingAlarmOptions) async throws -> Bool in
            struct Meta: AlarmMetadata {}
            
            guard let uuid = UUID(uuidString: options.id) else {
                print("[ExpoAlarmKit] Invalid UUID string: \(options.id)")
                return false
            }
            let launchAppOnDismiss = options.launchAppOnDismiss ?? false
            
            // Convert weekday ints to Locale.Weekday
            // JS passes 1=Sunday, 2=Monday, etc. (matching iOS Calendar weekday)
            let weekdayArray: [Locale.Weekday] = Array(Set(options.weekdays.compactMap { day -> Locale.Weekday? in
                switch day {
                case 1: return .sunday
                case 2: return .monday
                case 3: return .tuesday
                case 4: return .wednesday
                case 5: return .thursday
                case 6: return .friday
                case 7: return .saturday
                default: return nil
                }
            }))
            
            // Create relative schedule with time and recurrence
            let time = Alarm.Schedule.Relative.Time(hour: options.hour, minute: options.minute)
            let recurrence = Alarm.Schedule.Relative.Recurrence.weekly(weekdayArray)
            let schedule = Alarm.Schedule.relative(Alarm.Schedule.Relative(time: time, repeats: recurrence))
            
            // Create stop button
            let stopLabel = options.stopButtonLabel ?? "Stop"
            let stopColor = options.stopButtonColor != nil ? colorFromHex(options.stopButtonColor!) : Color.white
            let stopButton = AlarmButton(
                text: LocalizedStringResource(stringLiteral: stopLabel),
                textColor: stopColor,
                systemImageName: "stop.circle"
            )
            
            // No snooze button — see the note in rescheduleAlarmInBackground.
            let snoozeLabel = options.snoozeButtonLabel ?? "Snooze"
            let snoozeColor = options.snoozeButtonColor != nil ? colorFromHex(options.snoozeButtonColor!) : Color.white
            let snoozeButton = AlarmButton(
                text: LocalizedStringResource(stringLiteral: snoozeLabel),
                textColor: snoozeColor,
                systemImageName: "stop.circle"
            )

            // AlarmKit always renders a secondary button, so it can't be removed.
    // Wire it to the same dismiss intent as Stop: `.custom` runs our intent
    // instead of AlarmKit's native countdown, so whichever button the user taps
    // the alarm reschedules and a mapping is written.
            let alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: options.title),
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .custom
            )
            
            let presentation = AlarmPresentation(alert: alertPresentation)
            
            // Create countdown duration for snooze
            let countdownDuration = Alarm.CountdownDuration(
                preAlert: nil,
                postAlert: TimeInterval(options.snoozeDuration ?? (9 * 60))
            )
            
            // Create attributes
            let alarmTintColor = options.tintColor != nil ? colorFromHex(options.tintColor!) : Color.blue
            let attributes = AlarmAttributes<Meta>(
                presentation: presentation,
                metadata: Meta(),
                tintColor: alarmTintColor
            )
            
            // Determine sound
            let alarmSound: AlertConfiguration.AlertSound
            if let soundName = options.soundName, !soundName.isEmpty {
                alarmSound = .named(soundName)
            } else {
                alarmSound = .default
            }
            
            let appGroupId = ExpoAlarmKitStorage.appGroupIdentifier ?? ""
            let stopIntent: any LiveActivityIntent = launchAppOnDismiss
                ? AlarmDismissIntentWithLaunch(alarmId: options.id, payload: options.dismissPayload, appGroupIdentifier: appGroupId)
                : AlarmDismissIntent(alarmId: options.id, payload: options.dismissPayload, appGroupIdentifier: appGroupId)

            // Same intent as Stop — snooze must not be a way out of the challenge.
            let secondaryIntent: (any LiveActivityIntent)? = launchAppOnDismiss
                ? AlarmDismissIntentWithLaunch(alarmId: options.id, payload: options.dismissPayload, appGroupIdentifier: appGroupId)
                : AlarmDismissIntent(alarmId: options.id, payload: options.dismissPayload, appGroupIdentifier: appGroupId)

            // Create configuration with relative schedule
            let config = AlarmManager.AlarmConfiguration<Meta>(
                countdownDuration: countdownDuration,
                schedule: schedule,
                attributes: attributes,
                stopIntent: stopIntent,
                secondaryIntent: secondaryIntent,
                sound: alarmSound
            )
            
            do {
                try await AlarmManager.shared.schedule(id: uuid, configuration: config)
                // Real fire time, not a sentinel — this is what lets JS tell
                // that an alarm has already gone off without recomputing the
                // recurrence itself.
                let next = nextFireDate(hour: options.hour, minute: options.minute, weekdays: options.weekdays)
                ExpoAlarmKitStorage.setAlarm(id: options.id, value: next?.timeIntervalSince1970 ?? -1)
                if let delay = options.rescheduleDelaySeconds {
                    let rescheduleConfig = PersistentAlarmConfig(
                        originalAlarmId: options.id,
                        title: options.title,
                        soundName: options.soundName,
                        rescheduleDelaySeconds: delay,
                        backstopDelaySeconds: options.backstopDelaySeconds,
                        stopButtonLabel: options.stopButtonLabel,
                        stopButtonColor: options.stopButtonColor,
                        snoozeButtonLabel: options.snoozeButtonLabel,
                        snoozeButtonColor: options.snoozeButtonColor,
                        tintColor: options.tintColor,
                        snoozeDuration: options.snoozeDuration,
                        doSnoozeIntent: options.doSnoozeIntent ?? false,
                        launchAppOnSnooze: options.launchAppOnSnooze ?? false,
                        snoozePayload: options.snoozePayload,
                        dismissPayload: options.dismissPayload,
                        launchAppOnDismiss: options.launchAppOnDismiss ?? false
                    )
                    ExpoAlarmKitStorage.setRescheduleConfig(alarmId: options.id, config: rescheduleConfig)
                    // A one-time backstop covering the next occurrence only.
                    // Later occurrences get theirs when JS re-arms the repeating
                    // alarm after the challenge is completed.
                    if let next {
                        await armBackstopAlarm(for: options.id, config: rescheduleConfig, baseFireDate: next)
                    }
                }
                return true
            } catch {
                print("[ExpoAlarmKit] Failed to schedule repeating alarm: \(error)")
                return false
            }
        }

        // MARK: - Schedule Timer Alarm
        AsyncFunction("scheduleTimerAlarm") { (options: ScheduleTimerOptions) async throws -> Bool in
            struct Meta: AlarmMetadata {}
            
            guard let uuid = UUID(uuidString: options.id) else {
                print("[ExpoAlarmKit] Invalid UUID string: \(options.id)")
                return false
            }
            
            let launchAppOnDismiss = options.launchAppOnDismiss ?? false
            
            // Create countdown presentation with pause button
            let pauseLabel = options.pauseButtonLabel ?? "Pause"
            let pauseColor = options.pauseButtonColor != nil ? colorFromHex(options.pauseButtonColor!) : Color.blue
            let countdown = AlarmPresentation.Countdown(
                title: LocalizedStringResource(stringLiteral: options.title),
                pauseButton: AlarmButton(
                    text: LocalizedStringResource(stringLiteral: pauseLabel),
                    textColor: pauseColor,
                    systemImageName: "pause.circle"
                )
            )
            
            // Create paused presentation with resume button
            let resumeLabel = options.resumeButtonLabel ?? "Resume"
            let resumeColor = options.resumeButtonColor != nil ? colorFromHex(options.resumeButtonColor!) : Color.blue
            let paused = AlarmPresentation.Paused(
                title: LocalizedStringResource(stringLiteral: "\(options.title) (Paused)"),
                resumeButton: AlarmButton(
                    text: LocalizedStringResource(stringLiteral: resumeLabel),
                    textColor: resumeColor,
                    systemImageName: "play.circle"
                )
            )
            
            // Create alert presentation for when timer fires
            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: options.title)
            )
            
            let presentation = AlarmPresentation(alert: alert, countdown: countdown, paused: paused)
            
            // Create attributes with tint color
            let alarmTintColor = options.tintColor != nil ? colorFromHex(options.tintColor!) : Color.blue
            let attributes = AlarmAttributes<Meta>(
                presentation: presentation,
                metadata: Meta(),
                tintColor: alarmTintColor
            )
            
            // Determine sound
            let alarmSound: AlertConfiguration.AlertSound
            if let soundName = options.soundName, !soundName.isEmpty {
                alarmSound = .named(soundName)
            } else {
                alarmSound = .default
            }
            
            let appGroupId = ExpoAlarmKitStorage.appGroupIdentifier ?? ""
            let stopIntent: any LiveActivityIntent = launchAppOnDismiss
                ? AlarmDismissIntentWithLaunch(alarmId: options.id, payload: options.dismissPayload, appGroupIdentifier: appGroupId)
                : AlarmDismissIntent(alarmId: options.id, payload: options.dismissPayload, appGroupIdentifier: appGroupId)
            
            // Create timer configuration
            let config = AlarmManager.AlarmConfiguration<Meta>.timer(
                duration: options.duration,
                attributes: attributes,
                stopIntent: stopIntent,
                sound: alarmSound
            )
            
            do {
                try await AlarmManager.shared.schedule(id: uuid, configuration: config)
                // Store alarm metadata in App Group (store -2 for timer to indicate timer type)
                ExpoAlarmKitStorage.setAlarm(id: options.id, value: -2)
                return true
            } catch {
                print("[ExpoAlarmKit] Failed to schedule timer alarm: \(error)")
                return false
            }
        }
        
        // MARK: - Cancel Alarm
        AsyncFunction("cancelAlarm") { (id: String) -> Bool in
            guard let uuid = UUID(uuidString: id) else {
                print("[ExpoAlarmKit] Invalid UUID string: \(id)")
                return false
            }
            
            do {
                try AlarmManager.shared.cancel(id: uuid)
                // Otherwise the safety net outlives the alarm it was protecting
                // and rings after the user has already woken up.
                cancelBackstopChain(for: id)
                ExpoAlarmKitStorage.removeAlarm(id: id)
                ExpoAlarmKitStorage.removeLaunchAppOnDismiss(alarmId: id)
                ExpoAlarmKitStorage.removeRescheduleConfig(alarmId: id)
                return true
            } catch {
                print("[ExpoAlarmKit] Failed to cancel alarm: \(error)")
                return false
            }
        }
        
        // MARK: - Get All Alarms
        Function("getAllAlarms") { () -> [String] in
            return ExpoAlarmKitStorage.getAllAlarmIds()
        }

        // MARK: - Alarm Fire Times (id + scheduled fire time, from App Group)
        Function("getAlarmFireTimes") { () -> [[String: Any]] in
            return ExpoAlarmKitStorage.getAllAlarmEntries().map {
                ["id": $0.id, "fireEpoch": $0.fireEpoch]
            }
        }

        // MARK: - Alarm States (live, straight from AlarmKit)
        //
        // Unlike getAlarmFireTimes (an App Group cache we write ourselves) this
        // asks AlarmKit what it currently holds. `state` == "alerting" means the
        // alarm is ringing RIGHT NOW — the one signal that needs no inference.
        //
        // NOTE: this is the only place the module reads AlarmManager's alarm
        // list. If AlarmKit's API differs from what's assumed here, this is the
        // single function to adjust; everything else keeps working.
        AsyncFunction("getAlarmStates") { () async throws -> [[String: Any]] in
            guard #available(iOS 26.0, *) else { return [] }
            var result: [[String: Any]] = []
            for alarm in try await AlarmManager.shared.alarms {
                var entry: [String: Any] = ["id": alarm.id.uuidString]
                switch alarm.state {
                case .scheduled: entry["state"] = "scheduled"
                case .countdown: entry["state"] = "countdown"
                case .paused: entry["state"] = "paused"
                case .alerting: entry["state"] = "alerting"
                @unknown default: entry["state"] = "unknown"
                }
                result.append(entry)
            }
            return result
        }

        
        // MARK: - Remove Alarm (from App Group storage only)
        Function("removeAlarm") { (id: String) in
            ExpoAlarmKitStorage.removeAlarm(id: id)
            ExpoAlarmKitStorage.removeLaunchAppOnDismiss(alarmId: id)
            ExpoAlarmKitStorage.removeRescheduleConfig(alarmId: id)
            ExpoAlarmKitStorage.removeBackstop(alarmId: id)
        }
        
        // MARK: - Clear All Alarms (from App Group storage only)
        Function("clearAllAlarms") { () in
            ExpoAlarmKitStorage.clearAllAlarms()
        }
        
        // MARK: - Get Pending Rescheduled Alarms
        // Returns mappings written by AlarmDismissIntent when the app was not open.
        // Call this on app launch to reconcile alarm IDs after a background reschedule.
        Function("getPendingRescheduledAlarms") { () -> [[String: String]] in
            return ExpoAlarmKitStorage.getAllRescheduled().map { mapping in
                ["originalAlarmId": mapping.originalAlarmId, "newAlarmId": mapping.newAlarmId]
            }
        }

        // MARK: - Get Backstop Alarm IDs
        // The backstops currently armed. These never appear in the app's alarms
        // table, so an orphan sweep must be told to spare them.
        Function("getBackstopAlarmIds") { () -> [String] in
            return ExpoAlarmKitStorage.getAllBackstopIds()
        }

        // MARK: - Clear Pending Rescheduled Alarms
        // Call after consuming the mappings from getPendingRescheduledAlarms().
        Function("clearPendingRescheduledAlarms") { () in
            ExpoAlarmKitStorage.clearAllRescheduled()
        }

        // MARK: - Get Launch Payload
        Function("getLaunchPayload") { () -> [String: Any]? in
            let payload = ExpoAlarmKitModule.launchPayload
            ExpoAlarmKitModule.launchPayload = nil
            return payload
        }
    }
}
