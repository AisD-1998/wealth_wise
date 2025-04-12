import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationProvider extends ChangeNotifier {
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationTimeHourKey = 'notification_time_hour';
  static const String _notificationTimeMinuteKey = 'notification_time_minute';

  bool _notificationsEnabled = true;
  TimeOfDay _reminderTime =
      const TimeOfDay(hour: 20, minute: 0); // Default 8:00 PM

  bool get notificationsEnabled => _notificationsEnabled;
  TimeOfDay get reminderTime => _reminderTime;

  // This would be true in a real implementation
  bool get isInitialized => true;

  NotificationProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? true;

    final hour = prefs.getInt(_notificationTimeHourKey) ?? 20;
    final minute = prefs.getInt(_notificationTimeMinuteKey) ?? 0;
    _reminderTime = TimeOfDay(hour: hour, minute: minute);

    notifyListeners();
  }

  Future<void> toggleNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
    notifyListeners();

    // In a real implementation, we would schedule or cancel notifications here
    debugPrint('Notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    _reminderTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notificationTimeHourKey, time.hour);
    await prefs.setInt(_notificationTimeMinuteKey, time.minute);
    notifyListeners();

    // In a real implementation, we would reschedule notifications here
    debugPrint('Reminder time set to ${time.hour}:${time.minute}');
  }

  // For demonstration purposes - would show a real notification in production
  void showNotification({
    required int id,
    required String title,
    required String body,
  }) {
    if (!_notificationsEnabled) return;

    // Just log the notification for demo purposes
    debugPrint('NOTIFICATION:');
    debugPrint('ID: $id');
    debugPrint('Title: $title');
    debugPrint('Body: $body');
    debugPrint('Time: ${DateTime.now()}');
  }

  // For demonstration purposes - would schedule a daily reminder in production
  void scheduleDailyExpenseReminder(TimeOfDay time) {
    if (!_notificationsEnabled) return;

    setReminderTime(time);
    debugPrint(
        'Daily expense reminder scheduled for ${time.hour}:${time.minute}');
  }
}
