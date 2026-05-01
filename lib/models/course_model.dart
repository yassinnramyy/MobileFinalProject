import 'package:flutter/material.dart';

class Course {
  final String id;        // Unique ID for each course
  final String name;      // Course name e.g. "Mathematics"
  final int color;        // Color stored as integer
  final String icon;      // Icon name e.g. "math", "science"
  final String userId;    // Which user owns this course
  int taskCount;          // How many tasks belong to this course

  Course({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.userId,
    this.taskCount = 0,   // Default is 0 tasks
  });

  // Convert Course object → Map (to save in database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'userId': userId,
      'taskCount': taskCount,
    };
  }

  // Convert Map → Course object (to read from database)
  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'],
      name: map['name'],
      color: map['color'],
      icon: map['icon'],
      userId: map['userId'],
      taskCount: map['taskCount'] ?? 0,
    );
  }

  // Get the actual Color object from stored integer
  Color get courseColor => Color(color);
}