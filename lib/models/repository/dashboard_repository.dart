import 'dart:async';

import '../configurations/supabase_config.dart';
import '../entities/activity.dart';
import '../entities/day_trip.dart';
import '../entities/expense.dart';
import '../entities/whole_trip.dart';

abstract class IDashboardRepository {
  Future<WholeTrip?> getCurrentTrip(DateTime date);

  Future<DayTrip?> getDayTrip(String tripId, DateTime date);

  Future<List<Activity>> getActivities(String dayTripId);

  Future<List<Expense>> getExpenses(List<String> activityIds);
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

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
