import 'package:firebase_database/firebase_database.dart';

class RealtimeDatabaseService {
  final _db = FirebaseDatabase.instance;

  // =====================
  // TASK COMPLETION SYNC (Option 1)
  // =====================

  // Update task completion status in real-time
  Future<void> updateTaskCompletion(String userId, String taskId, bool isCompleted) async {
    await _db
        .ref('task_status/$userId/$taskId')
        .set({'isCompleted': isCompleted, 'updatedAt': DateTime.now().toIso8601String()});
  }

  // Listen to task completion changes in real-time
  Stream<bool> listenToTaskCompletion(String userId, String taskId) {
    return _db
        .ref('task_status/$userId/$taskId/isCompleted')
        .onValue
        .map((event) => (event.snapshot.value as bool?) ?? false);
  }

  // =====================
  // LIVE STATS SYNC (Option 3)
  // =====================

  // Update home screen stats in real-time
  Future<void> updateStats(String userId, int total, int dueToday, int completed) async {
    await _db.ref('stats/$userId').set({
      'total': total,
      'dueToday': dueToday,
      'completed': completed,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  // Listen to stats changes in real-time
  Stream<Map<String, int>> listenToStats(String userId) {
    return _db.ref('stats/$userId').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      return {
        'total': (data['total'] as int?) ?? 0,
        'dueToday': (data['dueToday'] as int?) ?? 0,
        'completed': (data['completed'] as int?) ?? 0,
      };
    });
  }

  // =====================
  // USER ONLINE STATUS
  // =====================

  // Set user as online
  Future<void> setOnline(String userId) async {
    await _db.ref('presence/$userId').set({
      'online': true,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }

  // Set user as offline
  Future<void> setOffline(String userId) async {
    await _db.ref('presence/$userId').set({
      'online': false,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }
}