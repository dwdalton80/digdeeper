import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/typography_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/subscription_service.dart';

// Top-level FCM background handler (required by firebase_messaging)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TypographyService().load();
  await ThemeService().load();
  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Dark status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  // Firebase must be initialized before SubscriptionService (which uses Firestore)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SubscriptionService.instance.init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions (iOS)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Notification tap routing — cold start
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    pendingNotificationRoute.value = _notificationRouteFor(initialMessage.data);
  }

  // Notification tap routing — backgrounded app
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    pendingNotificationRoute.value = _notificationRouteFor(message.data);
  });

  // Save FCM token to Firestore on sign-in (direct — not via Cloud Function)
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user == null) return;
    await Future.delayed(const Duration(seconds: 1));
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('fcmTokens')
            .doc(token)
            .set({
          'token': token,
          'registeredAt': FieldValue.serverTimestamp(),
          'platform': 'ios',
        });
      }
    } catch (e) {
      debugPrint('FCM registration error: $e');
    }
  });

  // Refresh FCM token when it rotates
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'registeredAt': FieldValue.serverTimestamp(),
        'platform': 'ios',
      });
    } catch (_) {}
  });

  runApp(const ProviderScope(child: DigDeeperApp()));
}

String _notificationRouteFor(Map<String, dynamic> data) {
  final type = data['type'] as String? ?? '';
  switch (type) {
    case 'group_digest':
    case 'prayer_request':
    case 'prayer_answered':
      return '/groups';
    case 'partner_encouragement':
    case 'partner_complete':
      return '/plans';
    default:
      return '/home';
  }
}
