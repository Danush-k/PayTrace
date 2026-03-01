import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents an installed UPI app on the device
class UpiAppInfo {
  final String packageName;
  final String appName;
  final String icon; // emoji fallback

  const UpiAppInfo({
    required this.packageName,
    required this.appName,
    required this.icon,
  });
}

/// UPI Service — app discovery + plain launch (no URI-based payment).
///
/// SBI (and some other banks) block ALL payments initiated via `upi://pay`
/// URI scheme. Instead, PayTrace:
/// 1. Shows payment details with copy buttons
/// 2. Opens the UPI app normally (no payment URI)
/// 3. User pastes UPI ID + enters amount inside the app
/// 4. NotificationListenerService detects the payment notification
class UpiService {
  static const _channel = MethodChannel('com.paytrace.paytrace/upi');

  /// Generate a unique transaction reference for internal tracking
  static String generateTxnRef() {
    final now = DateTime.now();
    final ts = now.millisecondsSinceEpoch.toString();
    final random = (now.microsecond % 10000).toString().padLeft(4, '0');
    return 'PT$ts$random';
  }

  /// Known UPI app packages for fallback discovery
  static const _knownUpiApps = [
    {'package': 'com.google.android.apps.nbu.paisa.user', 'name': 'Google Pay'},
    {'package': 'com.phonepe.app', 'name': 'PhonePe'},
    {'package': 'net.one97.paytm', 'name': 'Paytm'},
    {'package': 'in.org.npci.upiapp', 'name': 'BHIM'},
    {'package': 'com.whatsapp', 'name': 'WhatsApp Pay'},
    {'package': 'in.amazon.mShop.android.shopping', 'name': 'Amazon Pay'},
    {'package': 'com.dreamplug.androidapp', 'name': 'CRED'},
    {'package': 'com.csam.icici.bank.imobile', 'name': 'iMobile Pay'},
    {'package': 'com.mobikwik_new', 'name': 'MobiKwik'},
    {'package': 'com.freecharge', 'name': 'Freecharge'},
    {'package': 'money.jupiter', 'name': 'Jupiter'},
    {'package': 'com.epifi.paisa', 'name': 'Fi Money'},
    {'package': 'com.myairtelapp', 'name': 'Airtel Thanks'},
    {'package': 'com.sbi.upi', 'name': 'SBI Pay'},
    {'package': 'com.mgs.induspsp', 'name': 'IndusPay'},
    {'package': 'com.infrasoft.uboi', 'name': 'Union Bank'},
    {'package': 'com.lcode.nsdlbank', 'name': 'NSDL Jiffy'},
    {'package': 'com.slice', 'name': 'Slice'},
  ];

  /// Get list of installed UPI apps on the device.
  /// Combines system intent query + fallback package checks to maximize discovery.
  static Future<List<UpiAppInfo>> getInstalledUpiApps() async {
    final Map<String, UpiAppInfo> found = {}; // packageName → info, deduped

    // Method 1: System intent query (finds apps registered for upi:// scheme)
    try {
      final result = await _channel.invokeMethod('getUpiApps');
      final List<dynamic> apps =
          result != null ? result as List<dynamic> : [];

      for (final app in apps) {
        final map = Map<String, String>.from(app as Map);
        final packageName = map['packageName'] ?? '';
        final appName = map['appName'] ?? 'Unknown';
        if (packageName.isNotEmpty) {
          found[packageName] = UpiAppInfo(
            packageName: packageName,
            appName: appName,
            icon: _getAppIcon(appName),
          );
        }
      }
      debugPrint('PayTrace: System query found ${found.length} UPI apps');
    } on PlatformException catch (e) {
      debugPrint('PayTrace: getUpiApps error: ${e.code} - ${e.message}');
    }

    // Method 2: Check known packages individually (catches apps system query misses)
    final fallback = await _getFallbackApps();
    for (final app in fallback) {
      if (!found.containsKey(app.packageName)) {
        found[app.packageName] = app;
      }
    }

    debugPrint('PayTrace: Total discovered ${found.length} UPI apps');
    return found.values.toList();
  }

  /// Check known UPI app packages one by one using isAppInstalled
  static Future<List<UpiAppInfo>> _getFallbackApps() async {
    final List<UpiAppInfo> found = [];
    for (final app in _knownUpiApps) {
      try {
        final installed = await _channel.invokeMethod(
          'isAppInstalled',
          {'package': app['package']},
        );
        if (installed == true) {
          found.add(UpiAppInfo(
            packageName: app['package']!,
            appName: app['name']!,
            icon: _getAppIcon(app['name']!),
          ));
        }
      } catch (_) {
        // Skip this app
      }
    }
    debugPrint('PayTrace: Fallback found ${found.length} UPI apps');
    return found;
  }

  /// Launch a UPI app normally — NO payment URI, NO autofill.
  /// Just opens the app's home screen so the user can manually
  /// paste the UPI ID and enter the amount.
  static Future<bool> launchApp(String packageName) async {
    try {
      final result = await _channel.invokeMethod(
        'launchApp',
        {'package': packageName},
      );
      debugPrint('PayTrace: Plain launch $packageName → $result');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('PayTrace: launchApp error: ${e.code} - ${e.message}');
      return false;
    }
  }

  /// Check if notification listener permission is enabled
  static Future<bool> isNotificationAccessEnabled() async {
    try {
      final result = await _channel.invokeMethod('isNotificationAccessEnabled');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// Open notification listener settings so user can grant access
  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on PlatformException catch (e) {
      debugPrint('PayTrace: openNotificationSettings error: ${e.message}');
    }
  }

  /// Open the app's details page in Android system settings
  /// (Settings → Apps → PayTrace) so user can enable restricted settings
  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } on PlatformException catch (e) {
      debugPrint('PayTrace: openAppSettings error: ${e.message}');
    }
  }

  /// Force Android to rebind the NotificationListenerService
  /// (fixes NLS killed by battery optimization on some OEM phones)
  static Future<bool> rebindNotificationListener() async {
    try {
      final result = await _channel.invokeMethod('rebindNotificationListener');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('PayTrace: rebindNLS error: ${e.message}');
      return false;
    }
  }

  /// Send a test notification event through the pipeline to verify connectivity
  static Future<String> testNotificationPipeline() async {
    try {
      final result = await _channel.invokeMethod('testNotification');
      return result?.toString() ?? 'unknown';
    } on PlatformException catch (e) {
      return 'error: ${e.message}';
    }
  }

  static String _getAppIcon(String appName) {
    final name = appName.toLowerCase();
    if (name.contains('google') || name.contains('gpay')) return '💳';
    if (name.contains('phonepe')) return '📱';
    if (name.contains('paytm')) return '💰';
    if (name.contains('bhim')) return '🏦';
    if (name.contains('whatsapp')) return '💬';
    if (name.contains('amazon')) return '📦';
    if (name.contains('cred')) return '💎';
    if (name.contains('imobile') || name.contains('icici')) return '🏧';
    if (name.contains('mobikwik')) return '📲';
    if (name.contains('freecharge')) return '⚡';
    if (name.contains('jupiter')) return '🪐';
    if (name.contains('fi money') || name.contains('fi ')) return '💵';
    if (name.contains('airtel')) return '📡';
    if (name.contains('sbi')) return '🏛️';
    if (name.contains('slice')) return '🍕';
    if (name.contains('union')) return '🏦';
    return '📱';
  }
}
