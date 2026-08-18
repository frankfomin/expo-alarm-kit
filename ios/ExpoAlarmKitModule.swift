import ExpoModulesCore
import AlarmKit
import ActivityKit
import AppIntents
import SwiftUI

// MARK: - Storage Keys
private let alarmKeyPrefix = "ExpoAlarmKit.alarm:"
private let launchAppKeyPrefix = "ExpoAlarmKit.launchApp:"
private let rescheduleConfigKeyPrefix = "ExpoAlarmKit.rescheduleConfig:"
private let rescheduledKeyPrefix = "ExpoAlarmKit.rescheduled:"

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

        if let config = ExpoAlarmKitStorage.getRescheduleConfig(alarmId: self.alarmId) {
            await rescheduleAlarmInBackground(config: config, originalAlarmId: self.alarmId)
        }

        ExpoAlarmKitStorage.removeAlarm(id: self.alarmId)
        ExpoAlarmKitStorage.removeLaunchAppOnDismiss(alarmId: self.alarmId)
        ExpoAlarmKitStorage.removeRescheduleConfig(alarmId: self.alarmId)

        return .result()
    }
}

@available(iOS 26.0, *)
public struct PersistentAlarmConfig: Codable {
    let originalAlarmId: String
    let title: String
    let soundName: String?
    let rescheduleDelaySeconds: Double
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

// Schedules a new alarm from within an AppIntent perform() — runs without opening the app.
@available(iOS 26.0, *)
private func rescheduleAlarmInBackground(config: PersistentAlarmConfig, originalAlarmId: String) async {
    struct Meta: AlarmMetadata {}

    let newAlarmId = UUID()
    let newAlarmIdString = newAlarmId.uuidString
    let fireDate = Date().addingTimeInterval(config.rescheduleDelaySeconds)

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
        systemImageName: "clock.badge.checkmark"
    )

    let alertPresentation = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: config.title),
        stopButton: stopButton,
        secondaryButton: snoozeButton,
        secondaryButtonBehavior: .countdown
    )
    let presentation = AlarmPresentation(alert: alertPresentation)

    let countdownDuration = Alarm.CountdownDuration(
        preAlert: nil,
        postAlert: TimeInterval(config.snoozeDuration ?? (9 * 60))
    )

    let alarmTintColor = config.tintColor != nil ? colorFromHex(config.tintColor!) : Color.blue
    let attributes = AlarmAttributes<Meta>(
        presentation: presentation,
        metadata: Meta(),
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
        ? AlarmDismissIntentWithLaunch(alarmId: newAlarmIdString, payload: config.dismissPayload, appGroupIdentifier: appGroupId)
        : AlarmDismissIntent(alarmId: newAlarmIdString, payload: config.dismissPayload, appGroupIdentifier: appGroupId)

    let secondaryIntent: (any LiveActivityIntent)?
    if config.doSnoozeIntent {
        secondaryIntent = config.launchAppOnSnooze
            ? AlarmSnoozeIntentWithLaunch(alarmId: newAlarmIdString, payload: config.snoozePayload)
            : AlarmSnoozeIntent(alarmId: newAlarmIdString, payload: config.snoozePayload)
    } else {
        secondaryIntent = nil
    }

    let alarmConfig = AlarmManager.AlarmConfiguration<Meta>(
        countdownDuration: countdownDuration,
        schedule: .fixed(fireDate),
        attributes: attributes,
        stopIntent: stopIntent,
        secondaryIntent: secondaryIntent,
        sound: alarmSound
    )

    do {
        try await AlarmManager.shared.schedule(id: newAlarmId, configuration: alarmConfig)
        ExpoAlarmKitStorage.setAlarm(id: newAlarmIdString, value: fireDate.timeIntervalSince1970)
        // Carry the reschedule config forward so the next dismiss also reschedules
        let nextConfig = PersistentAlarmConfig(
            originalAlarmId: newAlarmIdString,
            title: config.title,
            soundName: config.soundName,
            rescheduleDelaySeconds: config.rescheduleDelaySeconds,
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
        ExpoAlarmKitStorage.setRescheduleConfig(alarmId: newAlarmIdString, config: nextConfig)
        // Record mapping so JS can reconcile alarm IDs when it next opens
        ExpoAlarmKitStorage.setRescheduled(originalAlarmId: originalAlarmId, newAlarmId: newAlarmIdString)
    } catch {
        print("[ExpoAlarmKit] Background reschedule failed: \(error)")
    }
}

// MARK: - App Intent for Alarm Dismissal (With App Launch)
@available(iOS 26.0, *)
public struct AlarmDismissIntentWithLaunch: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Dismiss Alarm"
    public static var description = IntentDescription("Handles alarm dismissal and opens app")
    public static var openAppWhenRun: Bool = true

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

        if let config = ExpoAlarmKitStorage.getRescheduleConfig(alarmId: self.alarmId) {
            await rescheduleAlarmInBackground(config: config, originalAlarmId: self.alarmId)
        }

        ExpoAlarmKitStorage.removeAlarm(id: self.alarmId)
        ExpoAlarmKitStorage.removeLaunchAppOnDismiss(alarmId: self.alarmId)
        ExpoAlarmKitStorage.removeRescheduleConfig(alarmId: self.alarmId)

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
            let doSnoozeIntent = options.doSnoozeIntent ?? false
            let launchAppOnSnooze = options.launchAppOnSnooze ?? false
            
            // Create stop button
            let stopLabel = options.stopButtonLabel ?? "Stop"
            let stopColor = options.stopButtonColor != nil ? colorFromHex(options.stopButtonColor!) : Color.white
            let stopButton = AlarmButton(
                text: LocalizedStringResource(stringLiteral: stopLabel),
                textColor: stopColor,
                systemImageName: "stop.circle"
            )
            
            // Create snooze button
            let snoozeLabel = options.snoozeButtonLabel ?? "Snooze"
            let snoozeColor = options.snoozeButtonColor != nil ? colorFromHex(options.snoozeButtonColor!) : Color.white
            let snoozeButton = AlarmButton(
                text: LocalizedStringResource(stringLiteral: snoozeLabel),
                textColor: snoozeColor,
                systemImageName: "clock.badge.checkmark"
            )
            
            // Create alert presentation with intent if needed
            let alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: options.title),
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .countdown
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

            let secondaryIntent: (any LiveActivityIntent)?
            if doSnoozeIntent {
                if launchAppOnSnooze {
                    secondaryIntent = AlarmSnoozeIntentWithLaunch(alarmId: options.id, payload: options.snoozePayload)
                } else {
                    secondaryIntent = AlarmSnoozeIntent(alarmId: options.id, payload: options.snoozePayload)
                }
            } else {
                secondaryIntent = nil
            }

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
            let doSnoozeIntent = options.doSnoozeIntent ?? false
            let launchAppOnSnooze = options.launchAppOnSnooze ?? false
            
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
            
            // Create snooze button
            let snoozeLabel = options.snoozeButtonLabel ?? "Snooze"
            let snoozeColor = options.snoozeButtonColor != nil ? colorFromHex(options.snoozeButtonColor!) : Color.white
            let snoozeButton = AlarmButton(
                text: LocalizedStringResource(stringLiteral: snoozeLabel),
                textColor: snoozeColor,
                systemImageName: "clock.badge.checkmark"
            )
            
            // Create alert presentation
            let alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: options.title),
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .countdown
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

            let secondaryIntent: (any LiveActivityIntent)?
            if doSnoozeIntent {
                if launchAppOnSnooze {
                    secondaryIntent = AlarmSnoozeIntentWithLaunch(alarmId: options.id, payload: options.snoozePayload)
                } else {
                    secondaryIntent = AlarmSnoozeIntent(alarmId: options.id, payload: options.snoozePayload)
                }
            } else {
                secondaryIntent = nil
            }

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
                ExpoAlarmKitStorage.setAlarm(id: options.id, value: -1)
                if let delay = options.rescheduleDelaySeconds {
                    let rescheduleConfig = PersistentAlarmConfig(
                        originalAlarmId: options.id,
                        title: options.title,
                        soundName: options.soundName,
                        rescheduleDelaySeconds: delay,
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

        
        // MARK: - Remove Alarm (from App Group storage only)
        Function("removeAlarm") { (id: String) in
            ExpoAlarmKitStorage.removeAlarm(id: id)
            ExpoAlarmKitStorage.removeLaunchAppOnDismiss(alarmId: id)
            ExpoAlarmKitStorage.removeRescheduleConfig(alarmId: id)
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
