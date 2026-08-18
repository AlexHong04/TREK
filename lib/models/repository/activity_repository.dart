import '../entities/activity.dart';
import '../configurations/supabase_config.dart';

class ActivityRepository {
  Future<bool> insertActivities(List<Activity> activities) async {
    try {
      final insertData = activities.map((a) => a.toJson()).toList();
      await SupabaseConfig.client.from('activities').insert(insertData);
      return true;
    } on Exception catch (e) {
      print('Repository Insert Error: $e');
      throw Exception('DB Error: $e');
    }
  }
}
