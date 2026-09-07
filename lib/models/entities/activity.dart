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
  final double? minAllocatedBudget;

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
    this.minAllocatedBudget,
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
    double? minAllocatedBudget,
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
      minAllocatedBudget: minAllocatedBudget ?? this.minAllocatedBudget,
    );
  }

  // directly retrieve data from Supabase
  factory Activity.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['date'] ?? json['start_date'];
    if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.now();
    }

    // 2. Safe number parser
    double parseDouble(dynamic value, [double fallback = 0.0]) {
      if (value == null) return fallback;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? fallback;
    }

    return Activity(
      activitiesId: (json['activities_id'] ?? json['activitiesId'] ?? '').toString(),
      destination: (json['destination'] ?? 'Activity').toString(),
      description: (json['description'] ?? '').toString(),
      activityImgUrl: (json['activity_img_url'] ?? json['activityImgUrl'] ?? '').toString(),
      date: parsedDate,
      allocatedBudget: parseDouble(json['allocated_budget'] ?? json['allocatedBudget']),
      status: (json['status'] ?? 'pending').toString(),
      startTime: json['start_time'] ?? json['startTime'],
      endTime: json['end_time'] ?? json['endTime'],
      duration: json['duration']?.toString(),
      activityCategory: (json['activity_category'] ?? json['activityCategory'] ?? 'General').toString(),
      isOverspend: (json['is_overspend'] ?? json['isOverspend']) as bool? ?? false,
      overspendAmount: parseDouble(json['overspend_amount'] ?? json['overspendAmount']),
      dayTripId: (json['day_trip_id'] ?? json['dayTripId'] ?? '').toString(),
      minAllocatedBudget: json['min_allocated_budget'] != null || json['minAllocatedBudget'] != null
          ? parseDouble(json['min_allocated_budget'] ?? json['minAllocatedBudget'])
          : null,
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
      if (isOverspend != null) 'is_overspend': isOverspend,
      if (overspendAmount != null) 'overspend_amount': overspendAmount,
      'day_trip_id': dayTripId,
      'min_allocated_budget': minAllocatedBudget,
    };
  }
}

class ItineraryGenerationResult {
  final List<Activity> activities;
  final double totalAllocatedBudget;
  final int wishlistItemsCoveredCount;
  final double estimatedExtraBudgetNeeded;

  ItineraryGenerationResult({
    required this.activities,
    required this.totalAllocatedBudget,
    required this.wishlistItemsCoveredCount,
    required this.estimatedExtraBudgetNeeded,
  });
}
