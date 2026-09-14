import 'dart:typed_data';
import 'package:Trek/models/local_data_source/shared_preferences_source.dart';
import 'package:Trek/view_models/ui_state/activity_ui_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../configurations/supabase_config.dart';
import '../entities/activity.dart';
import '../entities/whole_trip.dart';
import '../entities/day_trip.dart';
import '../../utils/id_generator.dart';

import 'i_itinerary_repository.dart';

class ItineraryRepository implements IItineraryRepository {
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
    required double remainingBalance,
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

      final String? currentAuthId = SupabaseConfig.client.auth.currentUser?.id;
      String customUserId = 'US0001';

      if (currentAuthId != null) {
        try {
          // Attempt to fetch custom user_id based on auth_id
          final userRes = await SupabaseConfig.client
              .from('user')
              .select('user_id')
              .eq('auth_id', currentAuthId)
              .maybeSingle();
          if (userRes != null && userRes['user_id'] != null) {
            customUserId = userRes['user_id'];
          }
        } catch (e) {
          try {
            // Fallback to 'users' table if the alias is different
            final userRes = await SupabaseConfig.client
                .from('users')
                .select('user_id')
                .eq('auth_id', currentAuthId)
                .maybeSingle();
            if (userRes != null && userRes['user_id'] != null) {
              customUserId = userRes['user_id'];
            }
          } catch (e2) {
            print('Error fetching custom user_id: $e2');
          }
        }
      }

      // Extract an image from the first activity to represent the whole trip
      String? tripImageUrl;
      if (activities.isNotEmpty) {
        tripImageUrl = await _uploadImageToStorage(
          activities.first.activityImgUrl,
          'trip_${newTripId}',
        );
      }

      DateTime parsedStartDate = DateTime.now();
      DateTime parsedEndDate = DateTime.now().add(const Duration(days: 3));

      try {
        final parts = datesText.split(' - ');
        if (parts.length == 2) {
          parsedStartDate = DateTime.parse(parts[0].trim());
          parsedEndDate = DateTime.parse(parts[1].trim());
        } else {
          // If only 1 date happens
          parsedStartDate = DateTime.parse(parts[0].trim());
          parsedEndDate = parsedStartDate;
        }
      } catch (e) {
        print('Error parsing datesText \'\$datesText\': \$e');
      }

      // Create WholeTrip Entity and Insert
      final wholeTrip = WholeTrip(
        tripId: newTripId,
        userId: customUserId,
        destination: destination,
        startDate: parsedStartDate,
        endDate: parsedEndDate,
        totalBudget: totalBudget,
        remainingBalance: totalBudget,
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
  @override
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
  @override
  Future<DayTrip> getCurrentDay(String dayId) async {
    debugPrint("get current day $dayId");
    try {
      final response = await SupabaseConfig.client
          .from('day_trips')
          .select()
          .eq('day_trip_id', dayId)
          .single();

      return DayTrip.fromJson(response);
    } on Exception catch (e) {
      print('Error getting current day: $e');
      throw Exception('DB Error during fetching current day: $e');
    }
  }

  //zhiqin
  @override
  Future<bool> updateOverspendDetails(DayTrip day, Activity activity) async {
    try {
      // Update day_trips
      await SupabaseConfig.client
          .from('day_trips')
          .update({
            'overspend_amount': day.overspendAmount,
            'overspend_category': day.overspendCategory,
            'is_overspend': day.isOverspend,
          })
          .eq('day_trip_id', day.dayTripId as Object);

      // Update activities
      await SupabaseConfig.client
          .from('activities')
          .update({
            'overspend_amount': activity.overspendAmount,
            'is_overspend': activity.isOverspend,
          })
          .eq('activities_id', activity.activitiesId);

      return true;
    } on Exception catch (e) {
      debugPrint('Error updating overspend details: $e');

      throw Exception('DB Error during updating overspend details: $e');
    }
  }

  // zhiqin
  Future<void> updateDayTopUpBudget(DayTrip day) async {
    if (day.dayTripId == null) {
      throw Exception('Cannot update daily topup budget: dayTripId is null.');
    }
    try {
      await SupabaseConfig.client
          .from('day_trips')
          .update({'topup_budget': day.topUpBudget})
          .eq('day_trip_id', day.dayTripId!);
    } on Exception catch (e) {
      print('Budget Recovery Update Balance Error: $e');
      throw Exception('DB Error: $e');
    }
  }

  // Reconciles a day's stored overspend (amount + flag) to the authoritative
  // net value, so stale per-day overspend amounts are cleaned up.
  Future<void> updateDayOverspend(DayTrip day) async {
    if (day.dayTripId == null) {
      throw Exception('Cannot update daily overspend: dayTripId is null.');
    }
    final double netOverspend = day.overspendAmount ?? 0.0;
    try {
      await SupabaseConfig.client
          .from('day_trips')
          .update({
            'overspend_amount': netOverspend,
            'is_overspend': netOverspend > 0,
          })
          .eq('day_trip_id', day.dayTripId!);
    } on Exception catch (e) {
      print('Budget Recovery Update Overspend Error: $e');
      throw Exception('DB Error: $e');
    }
  }

  // zhiqin
  @override
  Future<bool> updateCriticalDetails(String tripId) async {
    try {
      await SupabaseConfig.client
          .from('whole_trips')
          .update({'is_critical_budget': true})
          .eq('trip_id', tripId);
      return true;
    } on Exception catch (e) {
      debugPrint('Error updating critical details: $e');

      throw Exception('DB Error during updating critical details: $e');
    }
  }

  // zhiqin
  @override
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

  //zhiqin
  @override
  Future<WholeTrip> getTrip(String tripId) async {
    try {
      final res = await SupabaseConfig.client
          .from('whole_trips')
          .select()
          .eq('trip_id', tripId)
          .single();

      return WholeTrip.fromJson(res);
    } catch (e) {
      print('Error fetching latest trip: $e');
      rethrow;
    }
  }

  //zhiqin
  @override
  Future<List<DayTrip>> fetchDaysByTripId(String tripId) async {
    try {
      final res = await SupabaseConfig.client
          .from('day_trips')
          .select()
          .eq('trip_id', tripId);

      return (res as List).map((json) => DayTrip.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching days by trip ID: $e');
      rethrow;
    }
  }

  // zhiqin
  @override
  Future<WholeTrip> getTripByActivityId(String activityId) async {
    try {
      final activity = await getCurrentActivity(activityId);
      final dayTrip = await getCurrentDay(activity.dayTripId);

      final tripId = dayTrip.tripId;

      final trip = await getTrip(tripId);

      return trip;
    } catch (e) {
      print('Error fetching trip by activity ID: $e');
      rethrow;
    }
  }

  // kokhong
  @override
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
  @override
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
  @override
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

  // weisong
  @override
  Future<void> replaceTripActivities({
    required String tripId,
    required List<Activity> newActivities,
  }) async {
    if (newActivities.isEmpty) return;

    try {
      // 1. Extract target activity IDs to replace
      final newActivityIds = newActivities.map((a) => a.activitiesId).toList();

      // 2. Delete existing records for these activity IDs
      await SupabaseConfig.client
          .from('activities')
          .delete()
          .inFilter(
            'activities_id',
            newActivityIds,
          ); // Use your column name: 'activities_id' or 'activitiesId'

      // 3. Prepare payload mapped to Supabase database columns
      final records = newActivities
          .map(
            (activity) => {
              'activities_id': activity.activitiesId,
              'day_trip_id': activity.dayTripId,
              'destination': activity.destination,
              'description': activity.description,
              'activity_img_url': activity.activityImgUrl,
              'date': activity.date.toIso8601String(),
              'allocated_budget': activity.allocatedBudget,
              'overspend_amount': activity.overspendAmount,
              'status': activity.status,
              'start_time': activity.startTime,
              'end_time': activity.endTime,
              'duration': activity.duration,
              'activity_category': activity.activityCategory,
              'is_overspend': activity.isOverspend,
            },
          )
          .toList();

      // 4. Batch insert the replacement activities into Supabase
      await SupabaseConfig.client.from('activities').insert(records);
    } catch (e) {
      debugPrint('Error in replaceTripActivities: $e');
      throw Exception('DB Error: $e');
    }
  }

  // weisong
  // for all plans screen
  @override
  Future<List<WholeTrip>> fetchAllTrip() async {
    try {
      final authUser = SupabaseConfig.client.auth.currentUser;
      if (authUser == null) {
        debugPrint('fetchAllTrips: No authenticated user session found.');
        return [];
      }

      // 1. Resolve custom user_id from public.user using the auth email
      final userRecord = await SupabaseConfig.client
          .from('user')
          .select('user_id')
          .eq('email', authUser.email ?? '')
          .maybeSingle();

      final String? customUserId = userRecord?['user_id'] as String?;

      if (customUserId == null || customUserId.isEmpty) {
        debugPrint(
          'fetchAllTrips: User profile record not found for email ${authUser.email}',
        );
        return [];
      }

      debugPrint('fetchAllTrips: Fetching trips for user_id = $customUserId');

      // 2. Query Supabase strictly for this user_id
      final response = await SupabaseConfig.client
          .from('whole_trips')
          .select()
          .eq('user_id', customUserId)
          .neq('status', 'deleted')
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) => WholeTrip.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user trips: $e');
      throw Exception('DB Error: $e');
    }
  }

  // weisong
  // the trip and activities that filtered by user id
  @override
  Future<WholeTrip?> fetchLatestTrip() async {
    try {
      final now = DateTime.now();
      // Use start and end of day in UTC/local to safely match today's date boundaries
      final startOfTodayIso = DateTime(
        now.year,
        now.month,
        now.day,
      ).toUtc().toIso8601String();
      final endOfTodayIso = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return null;

      final userRecord = await SupabaseConfig.client
          .from('user')
          .select('user_id')
          .eq('email', user.email ?? '')
          .maybeSingle();

      final String userId = userRecord?['user_id'] as String? ?? user.id;

      // 1. Priority 1: Ongoing Trip
      // Checks for status == 'ongoing' OR a trip scheduled for today that isn't completed
      final ongoingData = await SupabaseConfig.client
          .from('whole_trips')
          .select()
          .eq('user_id', userId)
          .neq('status', 'completed')
          .neq('status', 'deleted')
          .or(
            'status.eq.ongoing,and(start_date.lte.$endOfTodayIso,end_date.gte.$startOfTodayIso)',
          )
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (ongoingData != null) {
        debugPrint('--> Found Ongoing/Today Trip: ${ongoingData['trip_id']}');
        return WholeTrip.fromJson(ongoingData);
      }

      // 2. Priority 2: Future Pending Trip (Must NOT have already ended)
      final pendingData = await SupabaseConfig.client
          .from('whole_trips')
          .select()
          .eq('user_id', userId)
          .eq('status', 'pending')
          .gt('start_date', endOfTodayIso) // Strictly in the future
          .order('start_date', ascending: true)
          .limit(1)
          .maybeSingle();

      if (pendingData != null) {
        debugPrint('--> Found Future Pending Trip: ${pendingData['trip_id']}');
        return WholeTrip.fromJson(pendingData);
      }

      // 3. Priority 3: Fallback to Completed / Expired Trips
      final completedData = await SupabaseConfig.client
          .from('whole_trips')
          .select()
          .eq('user_id', userId)
          .neq('status', 'deleted')
          .order('end_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (completedData != null) {
        debugPrint(
          '--> Found Completed/Past Trip: ${completedData['trip_id']}',
        );
        return WholeTrip.fromJson(completedData);
      }

      return null;
    } catch (e) {
      debugPrint('Error in fetchLatestTripWithCurrentUserId: $e');
      return null;
    }
  }

  // weisong
  @override
  Future<void> replaceRemainingActivities({
    required String dayTripId,
    required List<String> oldRemainingActivityIds,
    required List<Activity> newActivities,
  }) async {
    // 1. Only delete the uncompleted remaining slots that are actually being replaced
    if (oldRemainingActivityIds.isNotEmpty) {
      await SupabaseConfig.client
          .from('activities')
          .delete()
          .inFilter('activities_id', oldRemainingActivityIds);
    }

    // 2. Insert the new replacement activities
    final insertPayload = newActivities.map((a) => a.toJson()).toList();
    await SupabaseConfig.client.from('activities').insert(insertPayload);
  }

  // weisong
  @override
  Future<Map<String, dynamic>> fetchSpentSummaryByActivityIds(
    List<String> activityIds,
  ) async {
    if (activityIds.isEmpty) {
      return {'totalSpent': 0.0, 'activitySpentMap': <String, double>{}};
    }

    // Fetch all expense rows for these activities
    final response = await SupabaseConfig.client
        .from('expenses')
        .select('activities_id, total_amount')
        .inFilter('activities_id', activityIds);

    final List<dynamic> records = response as List<dynamic>;

    double totalSpent = 0.0;
    final Map<String, double> activityMap = {};

    for (final row in records) {
      final double amt = ((row['total_amount'] as num?)?.toDouble()) ?? 0.0;
      final String actId = row['activities_id']?.toString() ?? '';

      totalSpent += amt;
      if (actId.isNotEmpty) {
        activityMap[actId] = (activityMap[actId] ?? 0.0) + amt;
      }
    }

    return {'totalSpent': totalSpent, 'activitySpentMap': activityMap};
  }

  @override
  Future<void> deleteWholeTrip(String tripId) async {
    // Soft delete: the row is kept and only flagged, so a plan removed from the
    // "View All Plans" list stays recoverable and its expenses/history are
    // never destroyed. Every user-facing trip query filters 'deleted' out.
    await SupabaseConfig.client
        .from('whole_trips')
        .update({'status': 'deleted'})
        .eq('trip_id', tripId);
  }
}

class ActivityLocalCache implements ISharedPreferencesRepo {
  final ActivityLocalDataSource _localDataSource;
  final IItineraryRepository _itineraryRepository;

  ActivityLocalCache({
    ActivityLocalDataSource? localDataSource,
    IItineraryRepository? itineraryRepository,
  }) : _localDataSource = localDataSource ?? ActivityLocalDataSource(),
       _itineraryRepository = itineraryRepository ?? ItineraryRepository();

  @override
  Future<List<Activity>> getActivities(
    String tripId, {
    bool forceRefresh = false,
  }) async {
    // 1. Try reading from local cache
    if (!forceRefresh) {
      final cachedActivities = await _localDataSource.loadActivities(tripId);
      if (cachedActivities != null && cachedActivities.isNotEmpty) {
        return cachedActivities;
      }
    }

    // 2. Fallback to network/service
    // this is used when the local does not have the data.
    final freshActivities = await _itineraryRepository.fetchAllActivitiesByTrip(
      tripId,
    );

    // 3. Update local cache
    await _localDataSource.saveActivities(tripId, freshActivities);

    return freshActivities;
  }

  @override
  Future<void> saveActivitiesLocally(
    String tripId,
    List<Activity> activities,
  ) async {
    await _localDataSource.saveActivities(tripId, activities);
  }

  @override
  Future<void> clearLocalActivities(String tripId) async {
    await _localDataSource.clearActivities(tripId);
  }
}
