import { registerWebModule, NativeModule } from 'expo-modules-core';

export type AuthorizationStatus = 'authorized' | 'denied' | 'notDetermined';

export interface LaunchPayload {
  alarmId: string;
  payload: string | null;
}

export interface ScheduleAlarmOptions {
  id: string;
  epochSeconds: number;
  title: string;
  soundName?: string | null;
  launchAppOnDismiss?: boolean;
  doSnoozeIntent?: boolean;
  launchAppOnSnooze?: boolean;
  dismissPayload?: string | null;
  snoozePayload?: string | null;
  stopButtonLabel?: string | null;
  snoozeButtonLabel?: string | null;
  stopButtonColor?: string | null;
  snoozeButtonColor?: string | null;
  tintColor?: string | null;
  snoozeDuration?: number | null;
}

export interface ScheduleRepeatingAlarmOptions {
  id: string;
  hour: number;
  minute: number;
  weekdays: number[];
  title: string;
  soundName?: string | null;
  launchAppOnDismiss?: boolean;
  doSnoozeIntent?: boolean;
  launchAppOnSnooze?: boolean;
  dismissPayload?: string | null;
  snoozePayload?: string | null;
  stopButtonLabel?: string | null;
  snoozeButtonLabel?: string | null;
  stopButtonColor?: string | null;
  snoozeButtonColor?: string | null;
  tintColor?: string | null;
  snoozeDuration?: number | null;
}

class ExpoAlarmKitModule extends NativeModule {
  configure(appGroupIdentifier: string): boolean {
    console.warn('ExpoAlarmKit.configure is not supported on web');
    return false;
  }

  async requestAuthorization(): Promise<AuthorizationStatus> {
    console.warn('ExpoAlarmKit.requestAuthorization is not supported on web');
    return 'notDetermined';
  }

  generateUUID(): string {
    // Simple UUID v4 implementation for web
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  async scheduleAlarm(options: ScheduleAlarmOptions): Promise<boolean> {
    console.warn('ExpoAlarmKit.scheduleAlarm is not supported on web');
    return false;
  }

  async scheduleRepeatingAlarm(options: ScheduleRepeatingAlarmOptions): Promise<boolean> {
    console.warn('ExpoAlarmKit.scheduleRepeatingAlarm is not supported on web');
    return false;
  }

  async cancelAlarm(id: string): Promise<boolean> {
    console.warn('ExpoAlarmKit.cancelAlarm is not supported on web');
    return false;
  }

  getAllAlarms(): string[] {
    console.warn('ExpoAlarmKit.getAllAlarms is not supported on web');
    return [];
  }

  removeAlarm(id: string): void {
    console.warn('ExpoAlarmKit.removeAlarm is not supported on web');
  }

  clearAllAlarms(): void {
    console.warn('ExpoAlarmKit.clearAllAlarms is not supported on web');
  }

  getLaunchPayload(): LaunchPayload | null {
    console.warn('ExpoAlarmKit.getLaunchPayload is not supported on web');
    return null;
  }
}

export default registerWebModule(ExpoAlarmKitModule, 'ExpoAlarmKitModule');
