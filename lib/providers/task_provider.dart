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
  StreamSubscription? _connectivitySubscription;

  List<Task> _tasks = [];
  List<Course> _courses = [];
  bool _isLoading = false;
  String? _userId;

  final Set<String> _pendingTaskSync = {};
  final Set<String> _pendingCourseSync = {};
  final Set<String> _pendingTaskDeletes = {};
  final Set<String> _pendingCourseDeletes = {};

  List<Task> get tasks => _tasks;
  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;

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

  // =====================
  // INIT
  // =====================

  Future<void> init(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    await loadTasks();
    await loadCourses();
    await _realtimeDb.setOnline(userId);

    _connectivitySubscription = _connectivity.connectivityStream.listen((isOnline) {
      if (isOnline) {
        _syncPendingChanges();
      }
    });

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
      await _tasksSubscription?.cancel();
      _tasksSubscription = _firestoreService.getTasks(_userId!).listen((tasks) {
        _tasks = tasks;
        for (final task in tasks) {
          _db.insertTask(task);
        }
        _reconcileTaskCounts(); // ← recompute course task counts
        _syncStats();
        notifyListeners();
      });
    } else {
      _tasks = await _db.getTasks(_userId!);
      _reconcileTaskCounts(); // ← recompute course task counts
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

    await _db.insertTask(task);

    final online = await _connectivity.isOnline();
    if (online) {
      await _firestoreService.addTask(task);
    } else {
      _tasks.add(task);
      _pendingTaskSync.add(task.id);
      notifyListeners();
    }

    _syncStats();
  }

  Future<void> toggleTaskCompletion(String taskId) async {
    if (_userId == null) return;
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    _tasks[index].isCompleted = !_tasks[index].isCompleted;
    final isCompleted = _tasks[index].isCompleted;
    notifyListeners();

    await _db.updateTaskStatus(taskId, isCompleted);

    final online = await _connectivity.isOnline();
    if (online) {
      await _firestoreService.updateTask(_tasks[index]);
      await _realtimeDb.updateTaskCompletion(_userId!, taskId, isCompleted);
    } else {
      _pendingTaskSync.add(taskId);
    }

    _syncStats();
  }

  Future<void> deleteTask(String taskId) async {
    if (_userId == null) return;

    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();

    await _db.deleteTask(taskId);

    final online = await _connectivity.isOnline();
    if (online) {
      await _firestoreService.deleteTask(taskId);
      _pendingTaskDeletes.remove(taskId);
    } else {
      _pendingTaskSync.remove(taskId);
      _pendingTaskDeletes.add(taskId);
    }

    _syncStats();
  }

  // =====================
  // COURSE OPERATIONS
  // =====================

  Future<void> loadCourses() async {
    if (_userId == null) return;
    final online = await _connectivity.isOnline();

    if (online) {
      await _coursesSubscription?.cancel();
      _coursesSubscription = _firestoreService.getCourses(_userId!).listen((courses) {
        _courses = courses;
        for (final course in courses) {
          _db.insertCourse(course);
        }
        _reconcileTaskCounts(); // ← recompute course task counts
        notifyListeners();
      });
    } else {
      _courses = await _db.getCourses(_userId!);
      _reconcileTaskCounts(); // ← recompute course task counts
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

    await _db.insertCourse(course);

    final online = await _connectivity.isOnline();
    if (online) {
      await _firestoreService.addCourse(course);
    } else {
      _courses.add(course);
      _pendingCourseSync.add(course.id);
      notifyListeners();
    }
  }

  Future<void> deleteCourse(String courseId) async {
    if (_userId == null) return;

    _courses.removeWhere((c) => c.id == courseId);
    _tasks.removeWhere((t) => t.courseId == courseId);
    notifyListeners();

    await _db.deleteCourse(courseId);
    await _db.deleteTasksByCourse(courseId);

    final online = await _connectivity.isOnline();
    if (online) {
      await _firestoreService.deleteCourse(courseId);
      await _firestoreService.deleteTasksByCourse(_userId!, courseId);
      _pendingCourseDeletes.remove(courseId);
    } else {
      _pendingCourseSync.remove(courseId);
      _pendingCourseDeletes.add(courseId);
    }

    _syncStats();
  }

  // =====================
  // TASK COUNT RECONCILIATION
  // =====================

  // Recomputes taskCount on every Course object from the current _tasks list.
  // Call this whenever _tasks or _courses changes.
  void _reconcileTaskCounts() {
    _courses = _courses.map((course) {
      final count = _tasks.where((t) => t.courseId == course.id).length;
      return course.copyWith(taskCount: count);
    }).toList();
  }

  // =====================
  // OFFLINE → ONLINE SYNC
  // =====================

  Future<void> _syncPendingChanges() async {
    if (_userId == null) return;

    for (final taskId in Set.from(_pendingTaskDeletes)) {
      try {
        await _firestoreService.deleteTask(taskId);
        _pendingTaskDeletes.remove(taskId);
      } catch (_) {}
    }

    for (final courseId in Set.from(_pendingCourseDeletes)) {
      try {
        await _firestoreService.deleteCourse(courseId);
        await _firestoreService.deleteTasksByCourse(_userId!, courseId);
        _pendingCourseDeletes.remove(courseId);
      } catch (_) {}
    }

    for (final taskId in Set.from(_pendingTaskSync)) {
      try {
        final localTasks = await _db.getTasks(_userId!);
        final task = localTasks.firstWhere((t) => t.id == taskId);
        await _firestoreService.addTask(task);
        _pendingTaskSync.remove(taskId);
      } catch (_) {}
    }

    for (final courseId in Set.from(_pendingCourseSync)) {
      try {
        final localCourses = await _db.getCourses(_userId!);
        final course = localCourses.firstWhere((c) => c.id == courseId);
        await _firestoreService.addCourse(course);
        _pendingCourseSync.remove(courseId);
      } catch (_) {}
    }

    await loadTasks();
    await loadCourses();

    await _realtimeDb.setOnline(_userId!);
    _syncStats();
  }

  // =====================
  // REALTIME DB SYNC
  // =====================

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

  Stream<Map<String, int>> listenToStats() {
    if (_userId == null) return const Stream.empty();
    return _realtimeDb.listenToStats(_userId!);
  }

  // =====================
  // CLEANUP ON LOGOUT
  // =====================

  Future<void> dispose_user() async {
    if (_userId != null) {
      await _realtimeDb.setOffline(_userId!);
    }

    await _tasksSubscription?.cancel();
    await _coursesSubscription?.cancel();
    await _connectivitySubscription?.cancel();

    _tasks = [];
    _courses = [];
    _userId = null;
    _pendingTaskSync.clear();
    _pendingCourseSync.clear();
    _pendingTaskDeletes.clear();
    _pendingCourseDeletes.clear();

    notifyListeners();
  }
}