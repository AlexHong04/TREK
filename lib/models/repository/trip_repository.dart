import '../configurations/supabase_config.dart';
import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../entities/day_trip.dart';
import '../../utils/id_generator.dart';

class TripRepository {
  Future<void> insertFullTrip({
    required String destination,
    required String datesText,
    required double totalBudget,
    required List<Activity> activities,
  }) async {
    try {
      // 0. Auto-generate Sequential Formatted IDs
      final lastTripRes = await SupabaseConfig.client
          .from('whole_trips')
          .select('trip_id')
          .order('trip_id', ascending: false)
          .limit(1)
          .maybeSingle();
      String? lastTripId = lastTripRes?['trip_id'] as String?;
      String newTripId = IdGenerator.generateNextFormattedId('WI', lastTripId);

      // Create WholeTrip Entity and Insert
      final wholeTrip = WholeTrip(
        tripId: newTripId,
        userId: 'US0001',
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

      final lastDayTripRes = await SupabaseConfig.client
          .from('day_trips')
          .select('day_trip_id')
          .order('day_trip_id', ascending: false)
          .limit(1)
          .maybeSingle();
      String? lastDayTripId = lastDayTripRes?['day_trip_id'] as String?;
      String newDayTripId = IdGenerator.generateNextFormattedId(
        'DT',
        lastDayTripId,
      );

      // Create DayTrip Entity and Insert
      final dayTrip = DayTrip(
        dayTripId: newDayTripId,
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

      final lastActRes = await SupabaseConfig.client
          .from('activities')
          .select('activities_id')
          .order('activities_id', ascending: false)
          .limit(1)
          .maybeSingle();
      String? currentActId = lastActRes?['activities_id'] as String?;

      // Update Activity Entities and Insert
      final insertActivitiesData = activities.map((a) {
        final json = a.toJson();

        currentActId = IdGenerator.generateNextFormattedId('AC', currentActId);
        json['activities_id'] = currentActId;

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
