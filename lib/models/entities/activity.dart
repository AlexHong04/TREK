import 'package:flutter/material.dart';

class Activity {
  Activity({
    this.id,
    this.time,
    this.title,
    this.description,
    this.duration,
    this.cost,
    this.imagePath,
  });

  final String? id;
  final String? time;
  final String? title;
  final String? description;
  final String? duration;
  final String? cost;
  final String? imagePath;
}

class PreferenceItemModel {
  PreferenceItemModel({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
