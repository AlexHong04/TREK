import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../configurations/supabase_config.dart';
import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../entities/day_trip.dart';
import '../../utils/id_generator.dart';

class ItineraryRepository {
  // kokhong
  Future<String> _uploadImageToStorage(
    String externalUrl,
    String fileName,
  ) async {
    try {
      if (externalUrl.isEmpty || externalUrl.startsWith('assets/'))
        return externalUrl;

      final response = await http.get(Uri.parse(externalUrl));
      if (response.statusCode == 200) {
        final Uint8List imageBytes = response.bodyBytes;
        final String path =
            'images/$fileName-${DateTime.now().millisecondsSinceEpoch}.jpg';

        await SupabaseConfig.client.storage
            .from('itinerary_images')
            .uploadBinary(path, imageBytes);

        return SupabaseConfig.client.storage
            .from('itinerary_images')
            .getPublicUrl(path);
      }
    } catch (e) {
      print('Failed to upload image $externalUrl: $e');
    }
    return externalUrl; // Fallback to original if failed
  }

  // kokhong
  Future<void> insertFullTrip({
    required String destination,
    required String datesText,
    required double totalBudget,
    required List<Activity> activities,
  }) async {
    try {
      // Auto-generate Sequential Formatted IDs
      final lastTripRes = await SupabaseConfig.client
          .from('whole_trips')
          .select('trip_id')
          .order('trip_id', ascending: false)
          .limit(1)
          .maybeSingle();
      String? lastTripId = lastTripRes?['trip_id'] as String?;
      String newTripId = IdGenerator.generateNextFormattedId('WI', lastTripId);

      final String? currentUserId = SupabaseConfig.client.auth.currentUser?.id;

      // Extract an image from the first activity to represent the whole trip
      String? tripImageUrl;
      if (activities.isNotEmpty) {
        tripImageUrl = await _uploadImageToStorage(
          activities.first.activityImgUrl,
          'trip_${newTripId}',
        );
      }

      // Create WholeTrip Entity and Insert
      final wholeTrip = WholeTrip(
        tripId: newTripId,
        userId: currentUserId ?? 'US0001',
        destination: destination,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        totalBudget: totalBudget,
        status: 'pending',
        travelPreference: 'Nature',
        imgUrl: tripImageUrl,
      );

      final wholeTripResponse = await SupabaseConfig.client
          .from('whole_trips')
          .insert(wholeTrip.toJson())
          .select('trip_id')
          .single();

      final String tripId = wholeTripResponse['trip_id'];

      // Group activities by unique date
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

      // Insert DayTrip for each date group and link its activities
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

          // Upload activity image to Supabase Bucket
          String uploadedUrl = await _uploadImageToStorage(
            act.activityImgUrl,
            'act_${currentActId}',
          );

          json['activities_id'] = currentActId;
          json['day_trip_id'] = currentDayTripId;
          json['activity_img_url'] = uploadedUrl; // Replace with bucket URL!

          allUpdatedActivities.add(json);
        }
      }

      // Insert all activities
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

  // zhiqin
  Future<void> updateTripBudget(WholeTrip trip) async {
    if (trip.tripId == null) {
      throw Exception('Cannot update budget: tripId is null.');
    }

    try {
      await SupabaseConfig.client
          .from('whole_trips')
          .update({
            'remaining_balance': trip.remainingBalance,
            'total_budget': trip.totalBudget,
          })
          .eq('trip_id', trip.tripId!);
    } on Exception catch (e) {
      print('Budget Recovery Update Balance Error: $e');
      throw Exception('DB Error: $e');
    }
  }

  // zhiqin
  Future<void> terminateTrip(String id, String status) async {
    try {
      await SupabaseConfig.client
          .from('whole_trips')
          .update({'status': status})
          .eq('trip_id', id);
    } on Exception catch (e) {
      print('Budget Recovery End Trip Error: $e');
      throw Exception('DB Error: $e');
    }
  }

  // zhiqin
  Future<List<Activity>> fetchRemainingActivity(
    String tripId,
    String currentActivityId,
  ) async {
    try {
      // 1. Fetch all activities linked to the trip via day_trips
      final response = await SupabaseConfig.client
          .from('day_trips')
          .select('day_trip_id, activities(*)')
          .eq('trip_id', tripId);

      final List<Activity> allActivities = [];

      for (final dayTrip in response as List<dynamic>) {
        final activitiesList = dayTrip['activities'] as List<dynamic>? ?? [];
        for (final json in activitiesList) {
          allActivities.add(Activity.fromJson(json));
        }
      }

      // 2. Sort activities chronologically by date
      allActivities.sort((a, b) => a.date.compareTo(b.date));

      // 3. Find the index of the current activity
      final currentIndex = allActivities.indexWhere(
        (activity) => activity.activitiesId == currentActivityId,
      );

      // If current activity is not found, return all activities or handle gracefully
      if (currentIndex == -1) {
        return allActivities;
      }

      // 4. Return sublist starting AFTER the current activity
      return allActivities.sublist(currentIndex + 1);
    } on Exception catch (e) {
      print('Calculating Remaining Trip Cost Error: $e');
      throw Exception('DB Error: $e');
    }
  }

  //zhiqin
  Future<Activity> getCurrentActivity(String id) async {
    try {
      final response = await SupabaseConfig.client
          .from('activities')
          .select()
          .eq('activities_id', id)
          .single();

      return Activity.fromJson(response);
    } on Exception catch (e) {
      print('Error getting current activity: $e');
      throw Exception('DB Error during fetching current activity: $e');
    }
  }

  //zhiqin
  Future<DayTrip> getCurrentDay(String id) async {
    try {
      final response = await SupabaseConfig.client
          .from('day_trips')
          .select()
          .eq('activities_id', id)
          .single();

      return DayTrip.fromJson(response);
    } on Exception catch (e) {
      print('Error getting current activity: $e');
      throw Exception('DB Error during fetching current activity: $e');
    }
  }

  //zhiqin
  Future<DayTrip> updateDayOverspendDetails(DayTrip current) async {
    try {
      final response = await SupabaseConfig.client
          .from('day_trips')
          .update({
            'overspend_amount': current.overspendAmount,
            'overspend_category': current.overspendCategory,
            'is_overspend': current.isOverspend,
          })
          .eq('day_trip_id', current.dayTripId as Object);

      return DayTrip.fromJson(response as Map<String, dynamic>);
    } on Exception catch (e) {
      print('Error getting current activity: $e');
      throw Exception('DB Error during fetching current activity: $e');
    }
  }

  //zhiqin
  Future<Activity> updateOverspendDetails(Activity current) async {
    try {
      final response = await SupabaseConfig.client
          .from('activities')
          .update({
            'overspend_amount': current.overspendAmount,
            'is_overspend': current.isOverspend,
          })
          .eq('activities_id', current.activitiesId);

      return Activity.fromJson(response as Map<String, dynamic>);
    } on Exception catch (e) {
      print('Error getting current activity: $e');
      throw Exception('DB Error during fetching current activity: $e');
    }
  }

  // zhiqin
  Future<bool> updateActivities(List<Activity> activities) async {
    if (activities.isEmpty) return false;

    try {
      final List<Map<String, dynamic>> activitiesJson = activities
          .map((activity) => activity.toJson())
          .toList();

      await SupabaseConfig.client
          .from('activities')
          .upsert(activitiesJson, onConflict: 'activities_id');

      return true;
    } on Exception catch (e) {
      print('Error batch updating activities: $e');
      throw Exception('DB Error during activities update: $e');
    }
  }

  Future<WholeTrip?> getTrip(String tripId) async {
    try {
      final res = await SupabaseConfig.client
          .from('whole_trips')
          .select()
          .eq('trip_id', tripId);

      return WholeTrip.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      print('Error fetching latest trip: $e');
      rethrow;
    }
  }

  // kokhong
  Future<WholeTrip?> getLatestTrip() async {
    try {
      final res = await SupabaseConfig.client
          .from('whole_trips')
          .select('*')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        return WholeTrip.fromJson(res);
      }
    } catch (e) {
      print('Error fetching latest trip: $e');
      // Rethrow to let ViewModel handle the error state
      rethrow;
    }
    return null;
  }

  // weisong
  Future<List<Activity>> fetchAllActivitiesByTrip(String tripId) async {
    try {
      final response = await SupabaseConfig.client
          .from('day_trips')
          .select('day_trip_id, activities(*)')
          .eq('trip_id', tripId);

      final List<Activity> allActivities = [];

      for (final dayTrip in response as List<dynamic>) {
        final activitiesList = dayTrip['activities'] as List<dynamic>? ?? [];
        for (final json in activitiesList) {
          allActivities.add(
            Activity.fromJson(Map<String, dynamic>.from(json as Map)),
          );
        }
      }

      allActivities.sort((a, b) => a.date.compareTo(b.date));
      return allActivities;
    } catch (e) {
      print('Error fetching activities: $e');
      throw Exception('DB Error: $e');
    }
  }

  // weisong
  Future<void> updateTripStatus(String tripId, String newStatus) async {
    try {
      await SupabaseConfig.client
          .from('whole_trips')
          .update({'status': newStatus})
          .eq('trip_id', tripId);
    } catch (e) {
      print('Error updating trip status: $e');
      throw Exception('DB Error: $e');
    }
  }
}
