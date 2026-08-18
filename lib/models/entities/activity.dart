class Activity {
  final String activitiesId;
  final String destination;
  final String description;
  final String activityImgUrl;
  final DateTime date;
  final double allocatedBudget;
  final String status;
  final String? startTime;
  final String? endTime;
  final String? duration;
  final String activityCategory;
  final bool? isOverspend;
  final double? overspendAmount;
  final String dayTripId;

  Activity({
    required this.activitiesId,
    required this.destination,
    required this.description,
    required this.activityImgUrl,
    required this.date,
    required this.allocatedBudget,
    required this.status,
    this.startTime,
    this.endTime,
    this.duration,
    required this.activityCategory,
    required this.isOverspend,
    required this.overspendAmount,
    required this.dayTripId,
  });

  // directly retrieve data from Supabase
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      activitiesId: json['activities_id'],
      destination: json['destination'],
      description: json['description'],
      activityImgUrl: json['activity_img_url'],
      date: DateTime.parse(json['date']),
      allocatedBudget: (json['allocated_budget'] as num).toDouble(),
      status: json['status'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      duration: json['duration'],
      activityCategory: json['activity_category'],
      isOverspend: null,
      overspendAmount: null,
      dayTripId: json['day_trip_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // 'activities_id': activitiesId, // Let Supabase auto-generate if possible, or include it
      'destination': destination,
      'description': description,
      'activity_img_url': activityImgUrl,
      'date': date.toIso8601String(),
      'allocated_budget': allocatedBudget,
      'status': status,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
      'activity_category': activityCategory,
      'day_trip_id': dayTripId,
    };
  }
}
