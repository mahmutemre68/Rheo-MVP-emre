// Runs on a real (simulated) device: asks the OS what it is actually holding,
// rather than trusting that our Dart called the right methods.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rheo_app/logic/notification_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => Hive.initFlutter());

  testWidgets('reminders use the DEVICE timezone, not UTC', (tester) async {
    await notificationService.init();
    final zone = notificationService.timezoneName;
    print('SONUC zamanlama saat dilimi = $zone');
    // The old code called tz.setLocalLocation(tz.local), which is a no-op —
    // tz.local IS UTC until something sets it. A 20:00 reminder then fired at
    // 20:00 UTC, three hours late in Istanbul.
    expect(zone, isNot('UTC'),
        reason: 'UTC demek saat dilimi hic ayarlanmadi demek');
  });

  testWidgets('the switch cannot claim reminders are on when none are queued',
      (tester) async {
    await notificationService.init();

    // Notifications are NOT authorised here (requestPermissions opens a system
    // dialog no test can tap), so iOS silently drops every scheduling request.
    await notificationService.setEnabled(true);
    final queued = await notificationService.scheduledCount();
    print('SONUC izinsiz: kuyruk = $queued, anahtar = '
        '${notificationService.isEnabled}');

    expect(queued, 0, reason: 'izin yokken iOS zaten hicbir sey kuyruga almaz');
    // This is the fix: previously isEnabled stayed true here, so Settings said
    // "Daily Reminder: on" while nothing would ever arrive.
    expect(notificationService.isEnabled, isFalse,
        reason: 'hicbir sey zamanlanmadiysa anahtar acik gorunmemeli');
  });

  testWidgets('turning it off leaves nothing behind', (tester) async {
    await notificationService.init();
    await notificationService.setEnabled(false);
    expect(await notificationService.scheduledCount(), 0);
    expect(notificationService.isEnabled, isFalse);
    print('SONUC kapali durumda kuyruk bos, anahtar kapali');
  });
}
