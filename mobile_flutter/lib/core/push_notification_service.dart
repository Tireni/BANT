import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'mobile_api.dart';

enum BantPushIntentType {
  friendRequest,
  room,
}

class BantPushIntent {
  final BantPushIntentType type;
  final String? roomId;

  const BantPushIntent._(this.type, {this.roomId});

  const BantPushIntent.friendRequest()
      : this._(BantPushIntentType.friendRequest);

  const BantPushIntent.room(String roomId)
      : this._(BantPushIntentType.room, roomId: roomId);

  static BantPushIntent? fromData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == 'friend_request' || type == 'friend_request_accepted') {
      return const BantPushIntent.friendRequest();
    }
    if (type == 'room_started') {
      final roomId = data['room_id']?.toString();
      if (roomId != null && roomId.isNotEmpty) {
        return BantPushIntent.room(roomId);
      }
    }
    return null;
  }
}

@pragma('vm:entry-point')
Future<void> bantFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase can be unavailable in local/dev builds that do not yet include
    // google-services.json / GoogleService-Info.plist.
  }
}

class BantPushService {
  static const _channel = AndroidNotificationChannel(
    'bant_social',
    'BANT social',
    description: 'Friend requests and live room activity.',
    importance: Importance.high,
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final StreamController<BantPushIntent> _intents =
      StreamController<BantPushIntent>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;

  BantPushIntent? _pendingIntent;
  String? _lastRegisteredToken;
  bool _initialized = false;
  bool _available = false;

  Stream<BantPushIntent> get intents => _intents.stream;
  bool get available => _available;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _available = true;
    } catch (e) {
      debugPrint('BANT push disabled: Firebase is not configured: $e');
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            _publishIntent(
              BantPushIntent.fromData(
                Map<String, dynamic>.from(decoded),
              ),
            );
          }
        } catch (_) {}
      },
    );

    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedMessage);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _onOpenedMessage(initial);
    }
  }

  Future<void> registerCurrentDevice(MobileApi api) async {
    if (!_available) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      await _registerToken(api, token);

      _tokenSubscription ??= _messaging.onTokenRefresh.listen((nextToken) {
        unawaited(_registerToken(api, nextToken));
      });
    } catch (e) {
      debugPrint('BANT push token registration failed: $e');
    }
  }

  Future<void> _registerToken(MobileApi api, String token) async {
    if (token == _lastRegisteredToken) return;

    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : 'other';

    await api.registerPushToken(
      token: token,
      platform: platform,
    );
    _lastRegisteredToken = token;
  }

  Future<void> resetAfterSignOut() async {
    if (!_available) return;
    _lastRegisteredToken = null;
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }

  BantPushIntent? takePendingIntent() {
    final next = _pendingIntent;
    _pendingIntent = null;
    return next;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final intent = BantPushIntent.fromData(message.data);
    final notification = message.notification;

    if (notification != null) {
      final payload = jsonEncode(message.data);
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: notification.title ?? 'BANT',
        body: notification.body ?? '',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'bant_social',
            'BANT social',
            channelDescription: 'Friend requests and live room activity.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } else if (intent != null) {
      _publishIntent(intent);
    }
  }

  void _onOpenedMessage(RemoteMessage message) {
    _publishIntent(BantPushIntent.fromData(message.data));
  }

  void _publishIntent(BantPushIntent? intent) {
    if (intent == null) return;
    if (_intents.hasListener) {
      _intents.add(intent);
    } else {
      _pendingIntent = intent;
    }
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _intents.close();
  }
}
