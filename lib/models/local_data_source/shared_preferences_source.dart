import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../view_models/ui_state/activity_ui_state.dart';

class ActivityLocalDataSource {
  static const String _keyPrefix = 'cached_activities_';

  Future<void> saveActivities(String tripId, List<Activity> activities) async {
    if (tripId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = activities.map((a) => a.toJson()).toList();
      await prefs.setString('$_keyPrefix$tripId', jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<List<Activity>?> loadActivities(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$tripId');
      if (raw == null || raw.isEmpty) {
        debugPrint('[LocalCache] No cache found for key $_keyPrefix$tripId');
        return null;
      }

      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .map((item) => Activity.fromJson(item as Map<String, dynamic>))
          .toList();

      debugPrint('[LocalCache] Successfully restored ${list.length} activities for key: $_keyPrefix$tripId');
      return list;
    } catch (e, stack) {
      debugPrint('[LocalCache] Error loading activities for key $_keyPrefix$tripId: $e\n$stack');
      return null;
    }
  }

  Future<void> clearActivities(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$tripId');
  }
}