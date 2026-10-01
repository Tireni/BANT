import 'package:bant_mobile/core/invite_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bantInviteTokenFromUri', () {
    test('reads custom scheme invite token', () {
      expect(
        bantInviteTokenFromUri(Uri.parse('bant://invite/abc123TOKEN')),
        'abc123TOKEN',
      );
    });

    test('reads web invite token', () {
      expect(
        bantInviteTokenFromUri(
          Uri.parse('https://bant-demo.vercel.app/r/roomToken123'),
        ),
        'roomToken123',
      );
    });

    test('rejects unrelated BANT web path', () {
      expect(
        bantInviteTokenFromUri(
          Uri.parse('https://bant-demo.vercel.app/room/roomToken123'),
        ),
        isNull,
      );
    });

    test('rejects unrelated host', () {
      expect(
        bantInviteTokenFromUri(Uri.parse('https://example.com/r/token')),
        isNull,
      );
    });
  });
}
