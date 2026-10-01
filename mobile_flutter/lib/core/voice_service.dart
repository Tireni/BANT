import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceService {
  final SupabaseClient supabase;
  Room? room;

  VoiceService(this.supabase);

  bool get connected => room?.connectionState == ConnectionState.connected;

  Future<void> connect(String roomId) async {
    if (room != null) return;
    final response = await supabase.functions.invoke(
      'mobile-livekit-token',
      body: {'room_id': roomId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['token']?.toString();
    final url = data['url']?.toString();
    if (token == null || url == null) {
      throw Exception('Unable to create BANT voice session');
    }

    final nextRoom = Room();
    await nextRoom.connect(url, token);
    await nextRoom.localParticipant?.setMicrophoneEnabled(true);
    room = nextRoom;
  }

  Future<void> setMuted(bool muted) async {
    await room?.localParticipant?.setMicrophoneEnabled(!muted);
  }

  Future<void> disconnect() async {
    await room?.disconnect();
    await room?.dispose();
    room = null;
  }
}
