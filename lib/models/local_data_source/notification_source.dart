import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Handles notification permission and delivery through the tourist's device.
/// Reminder timing and message decisions belong to the ViewModel/service layer.
class NotificationSource {
  static const _channelId = 'expense_reminders';
  static const _channelName = 'Expense reminders';
  static const _budgetAlertChannelId = 'budget_alerts';
  static const _budgetAlertChannelName = 'Budget alerts';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _isTimeZoneInitialized = false;
  Future<bool>? _pendingPermissionRequest;
  Future<bool>? _pendingExactAlarmRequest;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _notifications.initialize(
      settings: initializationSettings,
    );
    await _initializeTimeZone();
    _isInitialized = true;
  }

  /// Configures timezone-aware dates so a reminder is scheduled in the
  /// tourist's device timezone instead of in UTC.
  Future<void> _initializeTimeZone() async {
    if (_isTimeZoneInitialized) {
      return;
    }

    tz.initializeTimeZones();
    final currentTimeZone = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));
    } catch (_) {
      // Some emulators report "GMT", while the timezone package uses UTC.
      tz.setLocalLocation(tz.UTC);
    }
    _isTimeZoneInitialized = true;
  }

  /// Requests the Android 13+ notification permission.
  /// Older Android versions do not require this runtime permission.
  Future<bool> requestPermission() async {
    final existingRequest = _pendingPermissionRequest;
    if (existingRequest != null) {
      return existingRequest;
    }

    final request = _requestNotificationPermission();
    _pendingPermissionRequest = request;

    try {
      return await request;
    } finally {
      _pendingPermissionRequest = null;
    }
  }

  Future<bool> _requestNotificationPermission() async {
    await initialize();

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Requests Android's approval for time-specific reminders. Android opens
  /// its Alarms & reminders settings page when this approval is still needed.
  Future<bool> requestExactAlarmPermission() async {
    final existingRequest = _pendingExactAlarmRequest;
    if (existingRequest != null) {
      return existingRequest;
    }

    final request = _requestExactAlarmPermission();
    _pendingExactAlarmRequest = request;

    try {
      return await request;
    } finally {
      _pendingExactAlarmRequest = null;
    }
  }

  Future<bool> _requestExactAlarmPermission() async {
    await initialize();

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return true;
    }

    final alreadyGranted =
        await androidPlugin.canScheduleExactNotifications() ?? true;
    if (alreadyGranted) {
      return true;
    }

    return await androidPlugin.requestExactAlarmsPermission() ?? false;
  }

  /// Schedules one reminder at [scheduledAt]. The caller decides the message
  /// and timing; this local data source only communicates with the device.
  Future<void> scheduleExpenseReminder({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    if (!scheduledAt.isAfter(DateTime.now())) {
      throw ArgumentError.value(
        scheduledAt,
        'scheduledAt',
        'A reminder must be scheduled in the future.',
      );
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Reminders to record travel expenses.',
        icon: '@mipmap/ic_launcher',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('reminder'),
      ),
    );

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Removes a previously scheduled reminder, for example after the tourist
  /// has recorded an expense for its activity.
  Future<void> cancelExpenseReminder(int id) async {
    await initialize();
    await _notifications.cancel(id: id);
  }

  /// Clears all local notifications scheduled by the app, for example when
  /// the tourist logs out so reminders from the previous account do not show.
  Future<void> cancelAllNotifications() async {
    await initialize();
    await _notifications.cancelAll();
  }

  /// Immediately posts a heads-up notification that plays the app's reminder
  /// sound. Used to alert the tourist the moment a recorded expense pushes an
  /// activity over / close to its budget, without waiting for a scheduled
  /// reminder. No permission dialog is triggered here; callers should only
  /// invoke this after notification permission has been granted.
  Future<void> showBudgetAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _budgetAlertChannelId,
        _budgetAlertChannelName,
        channelDescription: 'Alerts when an activity is near or over budget.',
        icon: '@mipmap/ic_launcher',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('reminder'),
      ),
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  /// Removes an instant budget alert from the notification shade after its
  /// sound has already been played, so repeated alerts never pile up.
  Future<void> dismissBudgetAlert(int id) async {
    await initialize();
    await _notifications.cancel(id: id);
  }
}
