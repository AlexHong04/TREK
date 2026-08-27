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
  final double? minPrice;
  final double? maxPrice;

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
    this.minPrice,
    this.maxPrice,
  });

  Activity copyWith({
    String? activitiesId,
    String? destination,
    String? description,
    String? activityImgUrl,
    DateTime? date,
    double? allocatedBudget,
    String? status,
    String? startTime,
    String? endTime,
    String? duration,
    String? activityCategory,
    bool? isOverspend,
    double? overspendAmount,
    String? dayTripId,
    double? minPrice,
    double? maxPrice,
  }) {
    return Activity(
      activitiesId: activitiesId ?? this.activitiesId,
      destination: destination ?? this.destination,
      description: description ?? this.description,
      activityImgUrl: activityImgUrl ?? this.activityImgUrl,
      date: date ?? this.date,
      allocatedBudget: allocatedBudget ?? this.allocatedBudget,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      activityCategory: activityCategory ?? this.activityCategory,
      isOverspend: isOverspend ?? this.isOverspend,
      overspendAmount: overspendAmount ?? this.overspendAmount,
      dayTripId: dayTripId ?? this.dayTripId,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }

  // directly retrieve data from Supabase
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      activitiesId: json['activities_id'],
      destination: json['destination'],
      description: json['description'],
      activityImgUrl: (json['activity_img_url'] ?? '').toString(),
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
      minPrice: json['min_price'] != null
          ? (json['min_price'] as num).toDouble()
          : (json['minPrice'] != null
                ? (json['minPrice'] as num).toDouble()
                : null),
      maxPrice: json['max_price'] != null
          ? (json['max_price'] as num).toDouble()
          : (json['maxPrice'] != null
                ? (json['maxPrice'] as num).toDouble()
                : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activities_id': activitiesId,
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
      // Do not include min_price/max_price here if we don't want Supabase insert failures,
      // or we can include them if wanted. Let's exclude them to be 100% safe.
    };
  }
}
