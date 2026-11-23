import 'dart:convert';
import 'dart:io';

import 'package:Trek/utils/ktmb_schedule.dart';
import 'package:Trek/utils/transit_schedule_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KtmbSchedule schedule;

  setUpAll(() {
    final raw = File('assets/ktmb_schedule.json').readAsStringSync();
    schedule = KtmbSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  group('KtmbSchedule', () {
    test('resolves common spellings to the same station', () {
      final a = schedule.resolveStation('KL Sentral');
      expect(a, isNotNull);
      expect(schedule.resolveStation('Kuala Lumpur Sentral Railway Station'), a);
      expect(schedule.resolveStation('Kuala Lumpur'), a);
      expect(schedule.resolveStation('Ipoh Railway Station'), isNotNull);
      expect(schedule.resolveStation('JB Sentral'), isNotNull);
      expect(schedule.resolveStation('Nowhere Land'), isNull);
    });

    test('KL Sentral -> Ipoh uses the fast ETS time (~2h-3h)', () {
      final minutes = schedule.typicalDurationMinutes('KL Sentral', 'Ipoh');
      expect(minutes, isNotNull);
      expect(minutes, inInclusiveRange(120, 180));
    });

    test('lists real departures for a normal weekday', () {
      // 2026-09-02 is a Wednesday inside the feed's validity window.
      final trains = schedule.departures(
        from: 'KL Sentral',
        to: 'Butterworth',
        date: DateTime(2026, 9, 2),
      );
      expect(trains, isNotEmpty);
      final times = trains.map((t) => t.departMinutes).toList();
      expect([...times]..sort(), times, reason: 'sorted by departure');
      expect(trains.every((t) => t.durationMinutes > 0), isTrue);
    });

    test('closestDeparture picks the nearest train to the chosen time', () {
      final train = schedule.closestDeparture(
        from: 'KL Sentral',
        to: 'Ipoh',
        date: DateTime(2026, 9, 2),
        timeMinutes: 9 * 60,
      );
      expect(train, isNotNull);
      expect((train!.departMinutes - 9 * 60).abs(), lessThan(180));
    });

    test('no train between unrelated or identical stations', () {
      expect(
        schedule.departures(
          from: 'Ipoh',
          to: 'Ipoh',
          date: DateTime(2026, 9, 2),
        ),
        isEmpty,
      );
    });
  });

  group('Hub coordinate / airport code matching', () {
    test('Penang Sentral is the Butterworth bus hub, not the airport', () {
      final c = TransitScheduleHelper.getHubCoordinates('Penang Sentral')!;
      expect(c[0], closeTo(5.39, 0.02)); // Butterworth, not Bayan Lepas (5.297)
    });

    test('"kua" inside Kuala... does not become Kuantan airport', () {
      expect(TransitScheduleHelper.resolveAirportCode('Kuala Terengganu Airport'), 'TGG');
      final c = TransitScheduleHelper.getHubCoordinates('Kuala Terengganu Airport');
      // Kuantan airport is at lng 103.209; Kuala Terengganu at 103.103.
      expect(c == null || (c[1] - 103.2094).abs() > 0.05, isTrue);
    });

    test('standalone IATA codes still match', () {
      expect(TransitScheduleHelper.resolveAirportCode('PEN'), 'PEN');
      expect(TransitScheduleHelper.resolveAirportCode('KUA'), 'KUA');
      expect(TransitScheduleHelper.getHubCoordinates('BKI')![0], closeTo(5.937, 0.01));
    });
  });

  group('Flight distance fallback', () {
    test('haversine is sane (KLIA -> Penang is ~330 km)', () {
      final km = TransitScheduleHelper.haversineKm(
        [2.7456, 101.7072],
        [5.2971, 100.2769],
      );
      expect(km, inInclusiveRange(300, 360));
    });

    test('a pair missing from the timetable gets a plausible block time', () {
      // Kuching <-> Tawau is not in the airline table.
      final minutes = TransitScheduleHelper.getEstimatedDurationMinutes(
        transitType: 'flight',
        fromLocation: 'Kuching Airport',
        toLocation: 'Tawau Airport',
      );
      expect(minutes, inInclusiveRange(80, 130));
      expect(minutes % 5, 0);
    });

    test('timetable pairs still win over the estimate', () {
      final minutes = TransitScheduleHelper.getEstimatedDurationMinutes(
        transitType: 'flight',
        fromLocation: 'KLIA',
        toLocation: 'Penang Airport',
      );
      expect(minutes, 60);
    });
  });
}
