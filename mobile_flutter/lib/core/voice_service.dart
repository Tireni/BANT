import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BantVoiceStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  error,
}

class VoiceService extends ChangeNotifier {
  static const MethodChannel _backgroundAudioChannel =
      MethodChannel('bant/background_audio');

  final SupabaseClient supabase;

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String? _roomId;

  BantVoiceStatus status = BantVoiceStatus.idle;
  bool selfMuted = false;
  bool adminMuted = false;
  bool speakerOn = true;
  bool canPublish = true;
  String? error;
  int remoteCount = 0;
  Set<String> connectedUserIds = <String>{};
  Set<String> activeSpeakerIds = <String>{};
  Set<String> mutedVoiceUserIds = <String>{};

  VoiceService(this.supabase);

  bool get connected =>
      _room?.connectionState == ConnectionState.connected &&
      status == BantVoiceStatus.connected;

  bool get muted => selfMuted || adminMuted || !canPublish;

  Future<void> connect(
    String roomId, {
    required bool publishMicrophone,
    bool startMuted = false,
  }) async {
    if (_roomId == roomId &&
        (status == BantVoiceStatus.connected ||
            status == BantVoiceStatus.connecting ||
            status == BantVoiceStatus.reconnecting)) {
      return;
    }

    await disconnect();

    _roomId = roomId;
    canPublish = publishMicrophone;
    selfMuted = false;
    adminMuted = startMuted;
    error = null;
    status = BantVoiceStatus.connecting;
    notifyListeners();

    try {
      if (publishMicrophone) {
        final microphoneStatus = await Permission.microphone.request();
        if (!microphoneStatus.isGranted) {
          if (microphoneStatus.isPermanentlyDenied) {
            throw Exception(
              'Microphone permission is permanently denied. Enable microphone access for BANT in Android settings.',
            );
          }
          throw Exception(
            'Microphone permission was denied. Allow microphone access to speak in BANT rooms.',
          );
        }
      }

      // Bluetooth permission improves headset routing on Android 12+.
      // Denial does not block normal speaker/earpiece audio.
      try {
        await Permission.bluetoothConnect.request();
      } catch (_) {}

      await _startBackgroundAudioService(
        microphone: publishMicrophone,
      );

      final response = await supabase.functions.invoke(
        'mobile-livekit-token',
        body: {'room_id': roomId},
      );

      if (response.status >= 400) {
        final data = response.data;
        final message = data is Map && data['error'] != null
            ? data['error'].toString()
            : 'Unable to create BANT voice session';
        throw Exception(message);
      }

      final data = Map<String, dynamic>.from(response.data as Map);
      final token = data['token']?.toString();
      final url = data['url']?.toString();

      if (token == null || token.isEmpty || url == null || url.isEmpty) {
        throw Exception('Unable to create BANT voice session');
      }

      final nextRoom = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      _room = nextRoom;
      _listener = nextRoom.createListener();

      _listener!
        ..on<RoomReconnectingEvent>((_) {
          status = BantVoiceStatus.reconnecting;
          notifyListeners();
        })
        ..on<RoomReconnectedEvent>((_) {
          status = BantVoiceStatus.connected;
          _syncRemoteCount();
          notifyListeners();
        })
        ..on<ParticipantConnectedEvent>((_) {
          _syncVoiceSnapshot();
          notifyListeners();
        })
        ..on<ParticipantDisconnectedEvent>((_) {
          _syncVoiceSnapshot();
          notifyListeners();
        })
        ..on<ActiveSpeakersChangedEvent>((event) {
          activeSpeakerIds = event.speakers
              .map((participant) => participant.identity)
              .where((identity) => identity.isNotEmpty)
              .toSet();
          _syncVoiceSnapshot();
          notifyListeners();
        })
        ..on<TrackMutedEvent>((_) {
          _syncVoiceSnapshot();
          notifyListeners();
        })
        ..on<TrackUnmutedEvent>((_) {
          _syncVoiceSnapshot();
          notifyListeners();
        })
        ..on<RoomDisconnectedEvent>((_) {
          if (status != BantVoiceStatus.error) {
            status = BantVoiceStatus.idle;
          }
          remoteCount = 0;
          connectedUserIds = <String>{};
          activeSpeakerIds = <String>{};
          mutedVoiceUserIds = <String>{};
          notifyListeners();
        });

      nextRoom.addListener(_onRoomChanged);

      await nextRoom.connect(url, token);

      await Hardware.instance.setSpeakerphoneOn(true);
      speakerOn = true;

      if (publishMicrophone) {
        await nextRoom.localParticipant?.setMicrophoneEnabled(!muted);
      }

      _syncVoiceSnapshot();
      status = BantVoiceStatus.connected;
      error = null;
      notifyListeners();
    } catch (e) {
      error = _friendlyError(e);
      status = BantVoiceStatus.error;
      notifyListeners();
      await _disposeRoom();
      await _stopBackgroundAudioService();
    }
  }

  Future<void> reconnectForRole(
    String roomId, {
    required bool publishMicrophone,
    bool startMuted = false,
  }) async {
    await disconnect();
    await connect(
      roomId,
      publishMicrophone: publishMicrophone,
      startMuted: startMuted,
    );
  }

  Future<void> toggleMute() async {
    if (!canPublish || _room?.localParticipant == null || adminMuted) return;

    selfMuted = !selfMuted;
    await _applyEffectiveMute();
  }

  Future<void> setAdminMuted(bool value) async {
    adminMuted = value;
    await _applyEffectiveMute();
  }

  Future<void> _applyEffectiveMute() async {
    if (!canPublish || _room?.localParticipant == null) {
      _syncVoiceSnapshot();
      notifyListeners();
      return;
    }

    try {
      await _room!.localParticipant!.setMicrophoneEnabled(!muted);
      _syncVoiceSnapshot();
      error = null;
      notifyListeners();
    } catch (e) {
      error = 'Unable to update microphone state.';
      notifyListeners();
    }
  }

  Future<void> toggleSpeaker() async {
    final next = !speakerOn;
    try {
      await Hardware.instance.setSpeakerphoneOn(next);
      speakerOn = next;
      error = null;
      notifyListeners();
    } catch (e) {
      error = 'Unable to change audio output.';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    status = BantVoiceStatus.idle;
    error = null;
    remoteCount = 0;
    connectedUserIds = <String>{};
    activeSpeakerIds = <String>{};
    mutedVoiceUserIds = <String>{};
    notifyListeners();
    await _disposeRoom();
    await _stopBackgroundAudioService();
    _roomId = null;
  }

  void _syncVoiceSnapshot() {
    final room = _room;
    if (room == null) {
      remoteCount = 0;
      connectedUserIds = <String>{};
      activeSpeakerIds = <String>{};
      mutedVoiceUserIds = <String>{};
      return;
    }

    final connected = <String>{};
    final mutedIds = <String>{};

    final local = room.localParticipant;
    if (local != null && local.identity.isNotEmpty) {
      connected.add(local.identity);
      if (muted || local.isMuted) {
        mutedIds.add(local.identity);
      }
    }

    for (final participant in room.remoteParticipants.values) {
      if (participant.identity.isEmpty) continue;
      connected.add(participant.identity);
      if (participant.hasAudio && participant.isMuted) {
        mutedIds.add(participant.identity);
      }
    }

    connectedUserIds = connected;
    mutedVoiceUserIds = mutedIds;
    activeSpeakerIds = activeSpeakerIds.intersection(connected);
    remoteCount = room.remoteParticipants.length;
  }

  void _syncRemoteCount() {
    _syncVoiceSnapshot();
  }

  void _onRoomChanged() {
    _syncVoiceSnapshot();
    notifyListeners();
  }

  Future<void> _disposeRoom() async {
    final room = _room;
    final listener = _listener;

    _room = null;
    _listener = null;

    if (room != null) {
      room.removeListener(_onRoomChanged);
      try {
        await room.disconnect();
      } catch (_) {}
    }

    if (listener != null) {
      try {
        await listener.dispose();
      } catch (_) {}
    }

    if (room != null) {
      try {
        await room.dispose();
      } catch (_) {}
    }
  }

  Future<void> _startBackgroundAudioService({
    required bool microphone,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _backgroundAudioChannel.invokeMethod<void>(
        'start',
        {'microphone': microphone},
      );
    } catch (e) {
      debugPrint('BANT background audio service could not start: $e');
    }
  }

  Future<void> _stopBackgroundAudioService() async {
    if (!Platform.isAndroid) return;
    try {
      await _backgroundAudioChannel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  String _friendlyError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '');
    final lower = raw.toLowerCase();

    if (lower.contains('permission') ||
        lower.contains('microphone') ||
        lower.contains('record_audio')) {
      return 'Microphone access is required for BANT voice. Allow microphone access in Android settings and try again.';
    }
    if (lower.contains('token') || lower.contains('401') || lower.contains('403')) {
      return 'BANT could not authorize this voice session. Rejoin the room and try again.';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return 'BANT could not connect to live audio. Check your internet connection and try again.';
    }

    return raw.isEmpty ? 'Unable to connect to BANT voice.' : raw;
  }

  @override
  void dispose() {
    unawaited(_disposeRoom());
    super.dispose();
  }
}
