import 'endpoint_secrets.dart';
import 'tracker_secrets.dart';
import 'info_pages.dart';

// ─────────────────────────────────────────────────────────────────────
// APP FACADE — single read-only surface for build-time constants
// ─────────────────────────────────────────────────────────────────────
// Everything that the runtime services need ends up here, including
// lazily-decoded secrets. The rest of the code base reads through this
// facade so the underlying storage scheme can change without touching
// call sites.
// ─────────────────────────────────────────────────────────────────────

class AppFacade {
  AppFacade._();

  // Identity
  static const String bundleSlug = 'com.chickhop.chickenhop';
  static const String storeSlug = 'com.chickhop.chickenhop';
  static const String displayTitle = 'Chicken Hop';
  static const String trackerAppId = '';

  // Public reach
  static const String privacyPolicyLink = kPrivacyPolicyLink;
  static const String supportLink = kSupportLink;
  static const String homeSiteLink = kHomeSiteLink;

  // Decoded secrets
  static String get verdictEndpoint => resolveVerdictEndpoint();
  static String get trackerDevKey => resolveTrackerKey();
  static String get firebaseSender => resolveFirebaseSender();

  // Behaviour knobs
  static const int pushPromoSnoozeSeconds = 259200; // 3 days
  static const int organicRetryDelaySeconds = 5; // GCD wait window
  static const int verdictTimeoutSeconds = 15;
  static const int dnsProbeTimeoutSeconds = 7; // VPN-friendly
  static const int offlineDebounceMs = 700; // VPN flap absorption

  // Notification surface
  static const String notificationChannelId = 'chickenhop_primary_channel';
  static const String notificationChannelName = 'Chicken Hop Alerts';
  static const String notificationIconRes = '@drawable/ic_chimney_spark';
}
