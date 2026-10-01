import 'package:bant_mobile/models/room.dart';
import 'package:bant_mobile/models/room_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BantRoom parses feed data', () {
    final room = BantRoom.fromJson({
      'id': 'room-1',
      'title': 'Tech Talk',
      'description': 'Android and web',
      'category': 'Technology',
      'privacy': 'public',
      'participant_count': 12,
      'speaker_count': 4,
      'max_participants': 50,
      'noise_control_enabled': true,
      'status': 'live',
      'created_at': '2026-10-01T12:00:00Z',
    });

    expect(room.id, 'room-1');
    expect(room.participantCount, 12);
    expect(room.speakerCount, 4);
    expect(room.maxParticipants, 50);
    expect(room.noiseControlEnabled, isTrue);
    expect(room.isLive, isTrue);
  });

  test('room detail excludes departed members and sorts roles', () {
    final room = BantRoomDetail.fromJson({
      'id': 'room-1',
      'title': 'Room',
      'owner_id': 'owner',
      'status': 'live',
      'room_members': [
        {
          'user_id': 'listener',
          'role': 'listener',
          'left_at': null,
          'profiles': {
            'id': 'listener',
            'display_name': 'Zed',
            'username': 'zed',
          },
        },
        {
          'user_id': 'owner',
          'role': 'owner',
          'left_at': null,
          'profiles': {
            'id': 'owner',
            'display_name': 'Owner',
            'username': 'owner',
          },
        },
        {
          'user_id': 'speaker',
          'role': 'speaker',
          'left_at': null,
          'profiles': {
            'id': 'speaker',
            'display_name': 'Alice',
            'username': 'alice',
          },
        },
        {
          'user_id': 'gone',
          'role': 'speaker',
          'left_at': '2026-10-01T13:00:00Z',
          'profiles': {
            'id': 'gone',
            'display_name': 'Gone',
            'username': 'gone',
          },
        },
      ],
    });

    expect(room.participantCount, 3);
    expect(room.speakerCount, 2);
    expect(room.participants.map((p) => p.id), ['owner', 'speaker', 'listener']);
    expect(room.participantFor('speaker')?.username, 'alice');
    expect(room.participantFor('gone'), isNull);
  });
}
