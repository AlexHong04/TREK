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

      debugPrint(
        '[LocalCache] Successfully restored ${list.length} activities for key: $_keyPrefix$tripId',
      );
      return list;
    } catch (e, stack) {
      debugPrint(
        '[LocalCache] Error loading activities for key $_keyPrefix$tripId: $e\n$stack',
      );
      return null;
    }
  }

  Future<void> clearActivities(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$tripId');
  }
}

class ExpenseDraftLocalDataSource {
  static const String _keyPrefix = 'expense_manual_draft_';
  static const String _fullKeyPrefix = 'expense_full_draft_v1_';

  String _key({
    required String userId,
    required String tripId,
    required String activityId,
  }) => '$_keyPrefix${userId}_${tripId}_$activityId';

  String _fullKey({
    required String userId,
    required String tripId,
    required String activityId,
  }) => '$_fullKeyPrefix${userId}_${tripId}_$activityId';

  Future<void> saveFullDraft({
    required String userId,
    required String tripId,
    required String activityId,
    required Map<String, dynamic> draft,
  }) async {
    if (userId.isEmpty || tripId.isEmpty || activityId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _fullKey(userId: userId, tripId: tripId, activityId: activityId),
      jsonEncode(draft),
    );
  }

  Future<Map<String, dynamic>?> loadFullDraft({
    required String userId,
    required String tripId,
    required String activityId,
  }) async {
    if (userId.isEmpty || tripId.isEmpty || activityId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      _fullKey(userId: userId, tripId: tripId, activityId: activityId),
    );
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (error) {
      debugPrint('[ExpenseDraft] Error loading full draft: $error');
      return null;
    }
  }

  Future<void> clearFullDraft({
    required String userId,
    required String tripId,
    required String activityId,
  }) async {
    if (userId.isEmpty || tripId.isEmpty || activityId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(
      _fullKey(userId: userId, tripId: tripId, activityId: activityId),
    );
  }

  Future<void> saveDraftItems({
    required String userId,
    required String tripId,
    required String activityId,
    required List<Map<String, dynamic>> items,
  }) async {
    if (userId.isEmpty || tripId.isEmpty || activityId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = _key(userId: userId, tripId: tripId, activityId: activityId);
    if (items.isEmpty) {
      await prefs.remove(key);
      return;
    }

    await prefs.setString(key, jsonEncode(items));
  }

  Future<List<Map<String, dynamic>>> loadDraftItems({
    required String userId,
    required String tripId,
    required String activityId,
  }) async {
    if (userId.isEmpty || tripId.isEmpty || activityId.isEmpty) {
      return const [];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(
        _key(userId: userId, tripId: tripId, activityId: activityId),
      );
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (error) {
      debugPrint('[ExpenseDraft] Error loading manual draft: $error');
      return const [];
    }
  }

  Future<void> clearDraftItems({
    required String userId,
    required String tripId,
    required String activityId,
  }) async {
    if (userId.isEmpty || tripId.isEmpty || activityId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(
      _key(userId: userId, tripId: tripId, activityId: activityId),
    );
  }
}
