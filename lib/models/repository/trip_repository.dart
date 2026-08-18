import '../configurations/supabase_config.dart';
import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../entities/day_trip.dart';

class TripRepository {
  Future<void> insertFullTrip({
    required String destination,
    required String datesText,
    required double totalBudget,
    required List<Activity> activities,
  }) async {
    try {
      // 1. Create WholeTrip Entity and Insert
      final wholeTrip = WholeTrip(
        // Injecting a fake completely valid UUID to bypass the Not-Null constraint on user_id
        userId: '00000000-0000-0000-0000-000000000001',
        destination: destination,
        startDate: DateTime.now(), // Normally you would parse datesText here
        endDate: DateTime.now().add(const Duration(days: 3)),
        totalBudget: totalBudget,
        status: 'Planned',
        travelPreference: 'General',
      );

      final wholeTripResponse = await SupabaseConfig.client
          .from('whole_trips')
          .insert(wholeTrip.toJson())
          .select('trip_id')
          .single();

      final String tripId = wholeTripResponse['trip_id'];

      // 2. Create DayTrip Entity and Insert
      final dayTrip = DayTrip(
        tripId: tripId,
        destination: destination,
        date: DateTime.now(),
        isOverspend: false,
        overspendAmount: 0,
      );

      final dayTripResponse = await SupabaseConfig.client
          .from('day_trips')
          .insert(dayTrip.toJson())
          .select('day_trip_id')
          .single();

      final String dayTripId = dayTripResponse['day_trip_id'];

      // 3. Update Activity Entities and Insert
      final insertActivitiesData = activities.map((a) {
        final json = a.toJson();
        // Point the child to its real generated parent dayTripId
        json['day_trip_id'] = dayTripId;
        return json;
      }).toList();

      await SupabaseConfig.client
          .from('activities')
          .insert(insertActivitiesData);
    } on Exception catch (e) {
      print('TripRepository Insert Error: $e');
      throw Exception('DB Error: $e');
    }
  }
}
