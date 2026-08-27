import 'dart:async';

import '../configurations/supabase_config.dart';
import '../entities/activity.dart';
import '../entities/day_trip.dart';
import '../entities/expense.dart';
import '../entities/whole_trip.dart';

abstract class IDashboardRepository {
  Future<WholeTrip?> getCurrentTrip(DateTime date);

  Future<WholeTrip?> getWholeTrip(String tripId);

  Future<DayTrip?> getDayTrip(String tripId, DateTime date);

  Future<List<DayTrip>> getDayTrips(String tripId);

  Future<List<Activity>> getActivities(String dayTripId);

  Future<List<Activity>> getActivitiesForDayTrips(List<String> dayTripIds);

  Future<List<Expense>> getExpenses(List<String> activityIds);

  Future<List<DateTime>> getAvailableDates(String userId);

  Future<List<WholeTrip>> getTripsForUser(String userId);
}

class DashboardRepository implements IDashboardRepository {
  static const _timeout = Duration(seconds: 10);

  @override
  Future<WholeTrip?> getCurrentTrip(DateTime date) async {
    final dateText = _dateOnly(date);
    final userId = SupabaseConfig.client.auth.currentUser?.id;

    try {
      final Map<String, dynamic>? response;
      if (userId == null) {
        response = await SupabaseConfig.client
            .from('whole_trips')
            .select()
            .lte('start_date', dateText)
            .gte('end_date', dateText)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle()
            .timeout(_timeout);
      } else {
        response = await SupabaseConfig.client
            .from('whole_trips')
            .select()
            .eq('user_id', userId)
            .lte('start_date', dateText)
            .gte('end_date', dateText)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle()
            .timeout(_timeout);
      }

      return response == null ? null : WholeTrip.fromJson(response);
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw Exception('Unable to retrieve the current trip: $error');
    }
  }

  @override
  Future<WholeTrip?> getWholeTrip(String tripId) async {
    try {
      final response = await SupabaseConfig.client
          .from('whole_trips')
          .select()
          .eq('trip_id', tripId)
          .limit(1)
          .maybeSingle()
          .timeout(_timeout);

      return response == null ? null : WholeTrip.fromJson(response);
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw Exception('Unable to retrieve the trip: $error');
    }
  }

  @override
  Future<DayTrip?> getDayTrip(String tripId, DateTime date) async {
    try {
      final response = await SupabaseConfig.client
          .from('day_trips')
          .select()
          .eq('trip_id', tripId)
          .eq('date', _dateOnly(date))
          .limit(1)
          .maybeSingle()
          .timeout(_timeout);

      return response == null ? null : DayTrip.fromJson(response);
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw Exception("Unable to retrieve today's trip: $error");
    }
  }

  @override
  Future<List<DayTrip>> getDayTrips(String tripId) async {
    try {
      final response = await SupabaseConfig.client
          .from('day_trips')
          .select()
          .eq('trip_id', tripId)
          .order('date')
          .timeout(_timeout);

      return response
          .map((json) => DayTrip.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw Exception('Unable to retrieve the trip days: $error');
    }
  }

  @override
  Future<List<Activity>> getActivities(String dayTripId) async {
    try {
      final response = await SupabaseConfig.client
          .from('activities')
          .select()
          .eq('day_trip_id', dayTripId)
          .order('start_time')
          .timeout(_timeout);

      return response
          .map((json) => Activity.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw Exception("Unable to retrieve today's activities: $error");
    }
  }

  @override
  Future<List<Activity>> getActivitiesForDayTrips(
    List<String> dayTripIds,
  ) async {
    if (dayTripIds.isEmpty) return const [];

    try {
      final response = await SupabaseConfig.client
          .from('activities')
          .select()
          .inFilter('day_trip_id', dayTripIds)
          .order('date')
          .order('start_time')
          .timeout(_timeout);

      return response
          .map((json) => Activity.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw Exception('Unable to retrieve the trip activities: $error');
    }
  }

  @override
  Future<List<Expense>> getExpenses(List<String> activityIds) async {
    if (activityIds.isEmpty) return const [];

    try {
      final response = await SupabaseConfig.client
          .from('expenses')
          .select()
          .inFilter('activities_id', activityIds)
          .timeout(_timeout);

      return response
          .map((json) => Expense.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw Exception("Unable to retrieve today's expenses: $error");
    }
  }

  @override
  Future<List<DateTime>> getAvailableDates(String userId) async {
    try {
      final tripRows = await SupabaseConfig.client
          .from('whole_trips')
          .select('trip_id')
          .eq('user_id', userId)
          .timeout(_timeout);
      final tripIds = tripRows
          .map((row) => row['trip_id']?.toString() ?? '')
          .where((tripId) => tripId.isNotEmpty)
          .toList();
      if (tripIds.isEmpty) return const [];

      final response = await SupabaseConfig.client
          .from('day_trips')
          .select('date')
          .inFilter('trip_id', tripIds)
          .order('date')
          .timeout(_timeout);

      final uniqueDates = <String, DateTime>{};
      for (final row in response) {
        final value = row['date']?.toString();
        if (value == null || value.isEmpty) continue;
        final parsed = DateTime.parse(value);
        final date = DateTime(parsed.year, parsed.month, parsed.day);
        uniqueDates[_dateOnly(date)] = date;
      }
      return uniqueDates.values.toList();
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw Exception('Unable to retrieve available dates: $error');
    }
  }

  @override
  Future<List<WholeTrip>> getTripsForUser(String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('whole_trips')
          .select()
          .eq('user_id', userId)
          .order('end_date', ascending: false)
          .timeout(_timeout);

      return response
          .map((json) => WholeTrip.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw Exception('Unable to retrieve trips: $error');
    }
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
