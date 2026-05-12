import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../core/connectivity_service.dart';
import '../data/local/database_helper.dart';
import '../data/remote/firestore_service.dart';
import '../data/remote/realtime_database_service.dart';
import '../models/task_model.dart';
import '../models/course_model.dart';


class TaskProvider extends ChangeNotifier {
  final _connectivity = ConnectivityService();
  final _db = DatabaseHelper.instance;
  final _firestoreService = FirestoreService();
  final _realtimeDb = RealtimeDatabaseService();

  StreamSubscription? _tasksSubscription;
  StreamSubscription? _coursesSubscription;
  List<Task> _tasks = [];
  List<Course> _courses = [];
  bool _isLoading = false;
  String? _userId;

  List<Task> get tasks => _tasks;
  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;

  // Stats getters (used by Realtime Database sync)
  int get totalTasks => _tasks.length;
  int get completedTasks => _tasks.where((t) => t.isCompleted).length;
  int get dueTodayTasks {
    final today = DateTime.now();
    return _tasks.where((t) {
      final due = t.dueDate;
      return due.year == today.year &&
          due.month == today.month &&
          due.day == today.day &&
          !t.isCompleted;
    }).length;
  }

  // Initialize provider with userId
  Future<void> init(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();
    await loadTasks();
    await loadCourses();
    // Set user online in Realtime Database
    await _realtimeDb.setOnline(userId);
    _isLoading = false;
    notifyListeners();
  }

  // =====================
  // TASK OPERATIONS
  // =====================

  Future<void> loadTasks() async {
    if (_userId == null) return;
    final online = await _connectivity.isOnline();
    if (online) {
      // Listen to Firestore stream
      await _tasksSubscription?.cancel();

      _tasksSubscription =
          _firestoreService.getTasks(_userId!).listen((tasks) {
        _tasks = tasks;
        // Sync to local DB
        for (final task in tasks) {
          _db.insertTask(task);
        }
        _syncStats();
        notifyListeners();
      });
    } else {
      // Load from local DB
      _tasks = await _db.getTasks(_userId!);
      _syncStats();
      notifyListeners();
    }
  }

  Future<void> addTask({
    required String title,
    required String description,
    required String courseId,
    required String courseName,
    required DateTime dueDate,
    required String priority,
  }) async {
    if (_userId == null) return;
    final task = Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      courseId: courseId,
      courseName: courseName,
      dueDate: dueDate,
      priority: priority,
      userId: _userId!,
    );

    // Always save locally
    await _db.insertTask(task);

    // Save to Firestore if online
    final online = await _connectivity.isOnline();
    if (online) {
      await _firestoreService.addTask(task);
    } else {
      _tasks.add(task);
    }
    _syncStats();
    notifyListeners();
  }

  Future<void> toggleTaskCompletion(String taskId) async {
    if (_userId == null) return;
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    _tasks[index].isCompleted = !_tasks[index].isCompleted;
    final isCompleted = _tasks[index].isCompleted;

    // Update local DB
    await _db.updateTaskStatus(taskId, isCompleted);

    final online = await _connectivity.isOnline();
    if (online) {
      // Update Firestore
      await _firestoreService.updateTask(_tasks[index]);
      // Update Realtime Database (live sync)
      await _realtimeDb.updateTaskCompletion(_userId!, taskId, isCompleted);
    }

    _syncStats();
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    if (_userId == null) return;

    await _db.deleteTask(taskId);

    final online = await _connectivity.isOnline();
    if (online) await _firestoreService.deleteTask(taskId);

    _tasks.removeWhere((t) => t.id == taskId);
    _syncStats();
    notifyListeners();
  }

  // =====================
  // COURSE OPERATIONS
  // =====================

  Future<void> loadCourses() async {
    if (_userId == null) return;
    final online = await _connectivity.isOnline();
    if (online) {
      await _coursesSubscription?.cancel();

      _coursesSubscription =
          _firestoreService.getCourses(_userId!).listen((courses) async {
        _courses = courses;
        for (final course in courses) {
          _db.insertCourse(course);
        }
        notifyListeners();
      });
    } else {
      _courses = await _db.getCourses(_userId!);
      notifyListeners();
    }
  }

  Future<void> addCourse({
    required String name,
    required int color,
    required String icon,
  }) async {
    if (_userId == null) return;

    final course = Course(
      id: const Uuid().v4(),
      name: name,
      color: color,
      icon: icon,
      userId: _userId!,
    );

    final online = await _connectivity.isOnline();

    // Always cache locally
    await _db.insertCourse(course);

    if (online) {
      // Firestore listener will update UI automatically
      await _firestoreService.addCourse(course);
    } else {
      // Offline mode needs manual UI update
      _courses.add(course);
      notifyListeners();
    }
  }

  Future<void> deleteCourse(String courseId) async {
    if (_userId == null) return;

    // Remove instantly from UI
    _courses.removeWhere((c) => c.id == courseId);
    _tasks.removeWhere((t) => t.courseId == courseId);

    notifyListeners();

    // Delete locally
    await _db.deleteCourse(courseId);
    await _db.deleteTasksByCourse(courseId);

    final online = await _connectivity.isOnline();

    if (online) {
      // Delete course remotely
      await _firestoreService.deleteCourse(courseId);

      // Delete all tasks inside that course remotely
      await _firestoreService.deleteTasksByCourse(
        _userId!,
        courseId,
      );
    }

    _syncStats();
  }

  // =====================
  // REALTIME DB SYNC
  // =====================

  // Push live stats to Realtime Database
  Future<void> _syncStats() async {
    if (_userId == null) return;
    final online = await _connectivity.isOnline();
    if (online) {
      await _realtimeDb.updateStats(
        _userId!,
        totalTasks,
        dueTodayTasks,
        completedTasks,
      );
    }
  }

  // Listen to live stats stream (used by Home Screen)
  Stream<Map<String, int>> listenToStats() {
    if (_userId == null) return const Stream.empty();
    return _realtimeDb.listenToStats(_userId!);
  }

  // Cleanup when user logs out
  Future<void> dispose_user() async {
    if (_userId != null) {
      await _realtimeDb.setOffline(_userId!);
    }

    await _tasksSubscription?.cancel();
    await _coursesSubscription?.cancel();

    _tasks = [];
    _courses = [];
    _userId = null;

    notifyListeners();
  }
}