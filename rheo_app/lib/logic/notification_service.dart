import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily reminder service.
///
/// The previous implementation held a Dart [Timer] and, when it fired, called
/// debugPrint. Neither half worked: a Timer lives in the app process, so iOS
/// and Android kill it as soon as the app leaves the foreground, and printing
/// to the debug console reaches nobody. The mascot messages below were written
/// and had never been delivered to a single user.
///
/// These are handed to the OS scheduler instead, so they arrive whether or not
/// the app is running. Because a repeating schedule can only carry one payload,
/// the next [_horizonDays] days are queued individually with rotating copy and
/// topped back up on every launch — a learner who opens the app at all keeps a
/// full fortnight of reminders ahead of them.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _settingsBox = 'rheo_settings';
  static const String _notifEnabledKey = 'notifications_enabled';
  static const String _notifHourKey = 'notification_hour';
  static const String _notifMinuteKey = 'notification_minute';

  /// Notification ids are ours to allocate; this block is reserved for the
  /// daily reminders so cancelling them never touches anything else.
  static const int _idBase = 4200;
  static const int _horizonDays = 14;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _pluginReady = false;
  bool _isEnabled = false;
  int _hour = 20; // Default: 8 PM
  int _minute = 0;
  Box? _box;

  /// Mascot notification messages (TR)
  static const List<NotificationMessage> mascotMessages = [
    NotificationMessage(
      title: '🦦 Kodlar paslanıyor!',
      body: 'Bugün henüz pratik yapmadın. Gel, birlikte çözelim!',
    ),
    NotificationMessage(
      title: '🦦 Serin bozulmasın!',
      body: 'Günlük hedefe ulaşmak için birkaç soru kaldı!',
    ),
    NotificationMessage(
      title: '🦦 Bugün commit atmadın mı?',
      body: 'En azından Rheo\'da birkaç soru çöz, beyni aktif tut!',
    ),
    NotificationMessage(
      title: '🔥 Streak tehlikede!',
      body: 'Günlük serini korumak için bir quiz oyna!',
    ),
    NotificationMessage(
      title: '🦦 Debug zamanı!',
      body: 'Yeni Bug Hunt soruları seni bekliyor. Bulabilecek misin?',
    ),
    NotificationMessage(
      title: '⚡ Hızlı mısın?',
      body: 'Time Attack modunda kendini test et!',
    ),
    NotificationMessage(
      title: '🦦 Öğrenme zamanı!',
      body: 'Günde 10 dakika pratik, haftalık 1 saat öğrenme demek!',
    ),
    NotificationMessage(
      title: '📊 ELO puanın yükseliyor!',
      body: 'Devam et, sıralamada yükseliyorsun!',
    ),
  ];

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'rheo_daily_reminder',
    'Günlük hatırlatma',
    channelDescription: 'Pratik yapmayı unutmaman için günlük hatırlatma',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  /// Initialize notification service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _box = await Hive.openBox(_settingsBox);
      _isEnabled = _box?.get(_notifEnabledKey, defaultValue: false) ?? false;
      _hour = _box?.get(_notifHourKey, defaultValue: 20) ?? 20;
      _minute = _box?.get(_notifMinuteKey, defaultValue: 0) ?? 0;
    } catch (e) {
      debugPrint('NotificationService settings load error: $e');
    }

    // The plugin has no web implementation; on web the service stays a no-op
    // rather than throwing on every call.
    if (!kIsWeb) {
      try {
        tzdata.initializeTimeZones();
        // tz.setLocalLocation(tz.local) was a no-op: tz.local IS UTC until
        // something sets it, so every reminder was scheduled in UTC. A learner
        // in Istanbul asking for 20:00 would have been woken at 23:00. Ask the
        // device for its IANA zone and use that.
        try {
          final name = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(name));
        } catch (e) {
          debugPrint('NotificationService timezone lookup failed: $e');
        }
        await _plugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
              // Asked for explicitly in requestPermissions() instead, so the
              // prompt appears when the learner opts in rather than on the
              // very first launch, where it is reliably declined.
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        );
        _pluginReady = true;
      } catch (e) {
        debugPrint('NotificationService plugin init error: $e');
      }
    }

    _isInitialized = true;
    // Re-queue on every launch: this is what keeps the rolling horizon full.
    // setEnabled re-verifies, so a permission revoked in Settings since the
    // last run flips our own switch off rather than lying about it.
    if (_isEnabled) await setEnabled(true);
  }

  /// Ask the OS for permission. Returns whether reminders are now on.
  Future<bool> requestPermissions() async {
    if (!_pluginReady) return false;

    try {
      bool granted = false;
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        granted = await _plugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        // POST_NOTIFICATIONS is required from Android 13; older versions
        // return null here and are granted by manifest alone.
        granted = await android?.requestNotificationsPermission() ?? true;
      }

      if (!granted) return false;
      await setEnabled(true);
      return true;
    } catch (e) {
      debugPrint('Notification permission error: $e');
      return false;
    }
  }

  /// Enable/disable notifications
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      await _box?.put(_notifEnabledKey, enabled);
    } catch (e) {
      debugPrint('NotificationService save error: $e');
    }
    if (!enabled) {
      await cancelAll();
      return;
    }
    // Verify rather than assume. If the OS queued nothing — almost always
    // because notifications are not authorised — the switch must go back to
    // off instead of telling the learner reminders are on.
    final queued = await _reschedule();
    if (queued == 0) {
      _isEnabled = false;
      try {
        await _box?.put(_notifEnabledKey, false);
      } catch (e) {
        debugPrint('NotificationService save error: $e');
      }
      debugPrint('NotificationService: nothing scheduled, reverting to off');
    }
  }

  /// Set reminder time
  Future<void> setReminderTime(int hour, int minute) async {
    _hour = hour;
    _minute = minute;
    try {
      await _box?.put(_notifHourKey, hour);
      await _box?.put(_notifMinuteKey, minute);
    } catch (e) {
      debugPrint('NotificationService save error: $e');
    }
    if (_isEnabled) await _reschedule();
  }

  /// Queue the next [_horizonDays] reminders, each with its own message.
  /// Returns how many the OS is actually holding afterwards — iOS silently
  /// drops scheduling requests from an app the user has not authorised, so
  /// "no exception" is not evidence that anything was scheduled.
  Future<int> _reschedule() async {
    if (!_pluginReady) return 0;
    try {
      await _cancelScheduled();
      for (var day = 0; day < _horizonDays; day++) {
        final when = _nextOccurrence(day);
        final msg = mascotMessages[day % mascotMessages.length];
        await _plugin.zonedSchedule(
          _idBase + day,
          msg.title,
          msg.body,
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('NotificationService schedule error: $e');
    }
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (e) {
      debugPrint('NotificationService pending check failed: $e');
      return 0;
    }
  }

  /// The reminder time [dayOffset] days from the next one due. Today's slot is
  /// skipped once it has passed, so enabling reminders at 21:00 for a 20:00
  /// reminder does not fire one immediately.
  tz.TZDateTime _nextOccurrence(int dayOffset) {
    final now = tz.TZDateTime.now(tz.local);
    var first =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, _hour, _minute);
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
    return first.add(Duration(days: dayOffset));
  }

  Future<void> _cancelScheduled() async {
    for (var day = 0; day < _horizonDays; day++) {
      await _plugin.cancel(_idBase + day);
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    if (_pluginReady) {
      try {
        await _cancelScheduled();
      } catch (e) {
        debugPrint('NotificationService cancel error: $e');
      }
    }
    _isEnabled = false;
    try {
      await _box?.put(_notifEnabledKey, false);
    } catch (e) {
      debugPrint('NotificationService save error: $e');
    }
  }

  /// Check if notifications are enabled
  bool get isEnabled => _isEnabled;

  /// How many reminders the OS is currently holding. 0 means none will arrive,
  /// whatever the switch says.
  Future<int> scheduledCount() async {
    if (!_pluginReady) return 0;
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (e) {
      return 0;
    }
  }

  /// The zone reminders are scheduled in — UTC would mean the timezone lookup
  /// failed and every reminder is offset by the learner's UTC offset.
  String get timezoneName => tz.local.name;

  /// Get reminder hour
  int get hour => _hour;

  /// Get reminder minute
  int get minute => _minute;

  /// Get a random mascot message
  NotificationMessage getRandomMessage() {
    final random = Random();
    return mascotMessages[random.nextInt(mascotMessages.length)];
  }
}

/// Notification message model
class NotificationMessage {
  final String title;
  final String body;

  const NotificationMessage({
    required this.title,
    required this.body,
  });
}

/// Global instance
final notificationService = NotificationService();
