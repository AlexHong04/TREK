import 'package:flutter/material.dart';

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
}

class PreferenceItemModel {
  PreferenceItemModel({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
