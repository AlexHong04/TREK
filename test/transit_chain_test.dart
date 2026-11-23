import 'package:Trek/models/entities/whole_trip.dart';
import 'package:Trek/models/services/i_itinerary_service.dart';
import 'package:Trek/models/services/i_profile_service.dart';
import 'package:Trek/utils/transit_schedule_helper.dart';
import 'package:Trek/view_models/presentation_logic/travel_information_input_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfile extends ChangeNotifier implements IProfileService {
  @override
  String get preferredCurrency => 'MYR';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeItinerary implements IItineraryService {
  @override
  Future<List<WholeTrip>> fetchAllTrip() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('isSameTravelArea', () {
    test('airport and city station in the same place match', () {
      expect(TransitScheduleHelper.isSameTravelArea('KLIA', 'KL Sentral'), isTrue);
      expect(
        TransitScheduleHelper.isSameTravelArea(
          'Penang International Airport',
          'Penang Sentral',
        ),
        isTrue,
      );
    });

    test('different places do not match', () {
      expect(
        TransitScheduleHelper.isSameTravelArea('Penang International Airport', 'Kuching Airport'),
        isFalse,
      );
      expect(TransitScheduleHelper.isSameTravelArea('KLIA', 'Ipoh Railway Station'), isFalse);
    });

    test('JB Sentral and Woodlands count as one crossing', () {
      expect(TransitScheduleHelper.isSameTravelArea('JB Sentral', 'Woodlands CIQ'), isTrue);
    });

    test('unknown places are neither accepted nor rejected', () {
      expect(TransitScheduleHelper.isSameTravelArea('Somewhere Unknown', 'KLIA'), isNull);
    });
  });

  group('validateTransit continuity', () {
    late TravelInformationInputViewModel vm;

    setUp(() {
      vm = TravelInformationInputViewModel(
        itineraryService: _FakeItinerary(),
        profileService: _FakeProfile(),
      );
      vm.toggleDestination('Penang');
      vm.addTransitLeg(); // arrivals: [start, T1 arrival], departures: [T1 dep, END]
      vm.updateArrivalLocation(0, 'KLIA');
      vm.updateDepartureLocation(0, 'KLIA');
      vm.updateArrivalLocation(1, 'Penang International Airport');
    });

    tearDown(() => vm.dispose());

    test('End Departure from a different region than the last arrival is rejected', () {
      vm.updateDepartureLocation(1, 'Kuching Airport');
      final error = vm.validateTransit();
      expect(error, isNotNull);
      expect(error, contains('Transit 1 arrives at "Penang International Airport"'));
      expect(error, contains('End Departure'));
      expect(error, contains('Kuching Airport'));
    });

    test('End Departure from the same region is accepted by this check', () {
      vm.updateDepartureLocation(1, 'Penang International Airport');
      final error = vm.validateTransit();
      expect(error ?? '', isNot(contains('leaves from')));
    });

    test('an unknown departure place is not rejected', () {
      vm.updateDepartureLocation(1, 'Some Unlisted Hub');
      final error = vm.validateTransit();
      expect(error ?? '', isNot(contains('leaves from')));
    });
  });
}
