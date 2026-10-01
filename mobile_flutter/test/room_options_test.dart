import 'package:bant_mobile/core/room_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room categories stay aligned with BANT web', () {
    expect(bantRoomCategories.first, 'Feed');
    expect(bantRoomCategories.last, 'General');
    expect(bantRoomCategories.length, 20);
    expect(bantRoomCategories.toSet().length, bantRoomCategories.length);
  });

  test('room capacity stays inside supported launch range', () {
    expect(bantRoomCapacityOptions, [5, 10, 15, 20, 30, 50, 75, 100]);
    expect(bantDefaultRoomCapacity, 20);
    expect(bantMinRoomCapacity, 5);
    expect(bantMaxRoomCapacity, 100);
  });
}
