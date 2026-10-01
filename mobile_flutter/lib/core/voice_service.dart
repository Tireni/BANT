import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BantVoiceStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  error,
}

class VoiceService extends ChangeNotifier {
  final SupabaseClient supabase;

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String? _roomId;

  BantVoiceStatus status = BantVoiceStatus.idle;
  bool muted = false;
  bool speakerOn = true;
  bool canPublish = true;
  String? error;
  int remoteCount = 0;

  VoiceService(this.supabase);

  bool get connected =>
      _room?.connectionState == ConnectionState.connected &&
      status == BantVoiceStatus.connected;

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
    muted = startMuted || !publishMicrophone;
    error = null;
    status = BantVoiceStatus.connecting;
    notifyListeners();

    try {
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
          _syncRemoteCount();
          notifyListeners();
        })
        ..on<ParticipantDisconnectedEvent>((_) {
          _syncRemoteCount();
          notifyListeners();
        })
        ..on<RoomDisconnectedEvent>((_) {
          if (status != BantVoiceStatus.error) {
            status = BantVoiceStatus.idle;
          }
          remoteCount = 0;
          notifyListeners();
        });

      nextRoom.addListener(_onRoomChanged);

      await nextRoom.connect(url, token);

      await Hardware.instance.setSpeakerphoneOn(true);
      speakerOn = true;

      if (publishMicrophone) {
        await nextRoom.localParticipant?.setMicrophoneEnabled(!startMuted);
        muted = startMuted;
      } else {
        muted = true;
      }

      _syncRemoteCount();
      status = BantVoiceStatus.connected;
      error = null;
      notifyListeners();
    } catch (e) {
      error = _friendlyError(e);
      status = BantVoiceStatus.error;
      notifyListeners();
      await _disposeRoom();
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
    if (!canPublish || _room?.localParticipant == null) return;

    final nextMuted = !muted;
    try {
      await _room!.localParticipant!.setMicrophoneEnabled(!nextMuted);
      muted = nextMuted;
      error = null;
      notifyListeners();
    } catch (e) {
      error = 'Unable to update microphone state.';
      notifyListeners();
    }
  }

  Future<void> setMuted(bool value) async {
    if (!canPublish || _room?.localParticipant == null) {
      muted = true;
      notifyListeners();
      return;
    }

    try {
      await _room!.localParticipant!.setMicrophoneEnabled(!value);
      muted = value;
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
    notifyListeners();
    await _disposeRoom();
    _roomId = null;
  }

  void _syncRemoteCount() {
    remoteCount = _room?.remoteParticipants.length ?? 0;
  }

  void _onRoomChanged() {
    _syncRemoteCount();
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
