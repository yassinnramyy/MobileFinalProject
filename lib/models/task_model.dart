import 'package:flutter/material.dart';

class Task {
  final String id;          // Unique ID for each task
  final String title;       // Task name e.g. "Study Chapter 3"
  final String description; // Extra details about the task
  final String courseId;    // Which course this task belongs to
  final String courseName;  // Course name (for display)
  final DateTime dueDate;   // When is it due
  final String priority;    // "low", "medium", or "high"
  bool isCompleted;         // Is the task done or not
  final String userId;      // Which user owns this task

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.courseId,
    required this.courseName,
    required this.dueDate,
    required this.priority,
    this.isCompleted = false, // Default is not completed
    required this.userId,
  });

  // Convert Task object → Map (to save in database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'courseId': courseId,
      'courseName': courseName,
      'dueDate': dueDate.toIso8601String(), // Convert date to text
      'priority': priority,
      'isCompleted': isCompleted ? 1 : 0,  // SQLite uses 1/0 for true/false
      'userId': userId,
    };
  }

  // Convert Map → Task object (to read from database)
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      courseId: map['courseId'],
      courseName: map['courseName'],
      dueDate: DateTime.parse(map['dueDate']), // Convert text back to date
      priority: map['priority'],
      isCompleted: map['isCompleted'] == 1,    // Convert 1/0 back to true/false
      userId: map['userId'],
    );
  }

  // Get color based on priority (for UI)
  Color get priorityColor {
    switch (priority) {
      case 'high':
        return const Color(0xFFF72585); // Pink/red
      case 'medium':
        return const Color(0xFFFF9F1C); // Orange
      default:
        return const Color(0xFF4361EE); // Blue
    }
  }
}