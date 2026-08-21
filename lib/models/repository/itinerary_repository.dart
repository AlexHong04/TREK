import '../configurations/supabase_config.dart';
import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../entities/day_trip.dart';
import '../../utils/id_generator.dart';

class ItineraryRepository {
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

      final String? currentUserId = SupabaseConfig.client.auth.currentUser?.id;

      // Create WholeTrip Entity and Insert
      final wholeTrip = WholeTrip(
        tripId: newTripId,
        userId: currentUserId ?? 'US0001',
        destination: destination,
        startDate: DateTime.now(), // Normally you would parse datesText here
        endDate: DateTime.now().add(const Duration(days: 3)),
        totalBudget: totalBudget,
        status: 'pending',
        travelPreference: 'Nature',
      );

      final wholeTripResponse = await SupabaseConfig.client
          .from('whole_trips')
          .insert(wholeTrip.toJson())
          .select('trip_id')
          .single();

      final String tripId = wholeTripResponse['trip_id'];

      // 1. Group activities by unique date
      Map<DateTime, List<Activity>> groupedActivities = {};
      for (var activity in activities) {
        final d = activity.date;
        final dateKey = DateTime(d.year, d.month, d.day);
        if (!groupedActivities.containsKey(dateKey)) {
          groupedActivities[dateKey] = [];
        }
        groupedActivities[dateKey]!.add(activity);
      }

      final lastDayTripRes = await SupabaseConfig.client
          .from('day_trips')
          .select('day_trip_id')
          .order('day_trip_id', ascending: false)
          .limit(1)
          .maybeSingle();
      String? currentDayTripId = lastDayTripRes?['day_trip_id'] as String?;

      final lastActRes = await SupabaseConfig.client
          .from('activities')
          .select('activities_id')
          .order('activities_id', ascending: false)
          .limit(1)
          .maybeSingle();
      String? currentActId = lastActRes?['activities_id'] as String?;

      List<Map<String, dynamic>> allUpdatedActivities = [];

      // 2. Insert DayTrip for each date group and link its activities
      for (var entry in groupedActivities.entries) {
        final dateKey = entry.key;
        final actsInDay = entry.value;

        currentDayTripId = IdGenerator.generateNextFormattedId(
          'DT',
          currentDayTripId,
        );

        final dayTrip = DayTrip(
          dayTripId: currentDayTripId,
          tripId: tripId,
          destination: destination,
          date: dateKey,
          isOverspend: false,
          overspendAmount: 0,
        );

        await SupabaseConfig.client.from('day_trips').insert(dayTrip.toJson());

        for (var act in actsInDay) {
          final json = act.toJson();
          currentActId = IdGenerator.generateNextFormattedId(
            'AC',
            currentActId,
          );
          json['activities_id'] = currentActId;
          json['day_trip_id'] = currentDayTripId;
          allUpdatedActivities.add(json);
        }
      }

      // 3. Insert all activities
      if (allUpdatedActivities.isNotEmpty) {
        await SupabaseConfig.client
            .from('activities')
            .insert(allUpdatedActivities);
      }
    } on Exception catch (e) {
      print('TripRepository Insert Error: $e');
      throw Exception('DB Error: $e');
    }
  }
}
