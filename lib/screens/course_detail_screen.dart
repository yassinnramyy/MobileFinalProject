import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../data/local/database_helper.dart';
import '../models/course_model.dart';
import '../models/task_model.dart';
import '../core/connectivity_service.dart';
import 'home_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;
  final _connectivity = ConnectivityService();

  Course? _course;
  List<Task> _tasks = [];
  List<Task> _upcoming = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  IconData _courseIcon(String icon) {
    switch (icon) {
      case 'calculus':
      case 'math':
        return Icons.functions;
      case 'chemistry':
      case 'science':
        return Icons.science;
      case 'globe':
        return Icons.public;
      case 'palette':
        return Icons.palette;
      case 'code':
        return Icons.code;
      case 'music':
        return Icons.music_note;
      case 'psych':
        return Icons.psychology;
      default:
        return Icons.book_outlined;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFF72585);
      case 'medium':
        return const Color(0xFF4361EE);
      default:
        return const Color(0xFF4CC9F0);
    }
  }

  Task _taskFromData(String id, Map<String, dynamic> data) {
    return Task(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      priority: data['priority'] ?? 'low',
      isCompleted: data['isCompleted'] ?? false,
      userId: data['userId'] ?? '',
    );
  }

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    final online = await _connectivity.isOnline();
    try {
      if (online) {
        final doc = await _firestore.collection('courses').doc(widget.courseId).get();
        if (doc.exists) {
          final d = doc.data()!;
          _course = Course(
            id: doc.id,
            name: d['name'] ?? '',
            color: d['color'] ?? 0xFF4361EE,
            icon: d['icon'] ?? 'book',
            userId: d['userId'] ?? '',
            taskCount: d['taskCount'] ?? 0,
          );
        }

        final tasksSnap = await _firestore
            .collection('tasks')
            .where('courseId', isEqualTo: widget.courseId)
            .where('userId', isEqualTo: user.id)
            .get();
        _tasks = tasksSnap.docs.map((d) => _taskFromData(d.id, d.data())).toList();
        _tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        _upcoming = _tasks.take(5).toList();
      } else {
        final courses = await _db.getCourses(user.id);
        try {
          _course = courses.firstWhere((c) => c.id == widget.courseId);
        } catch (_) {
          _course = null;
        }

        final allTasks = await _db.getTasks(user.id);
        _tasks = allTasks.where((t) => t.courseId == widget.courseId).toList();
        _tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        _upcoming = _tasks.take(5).toList();
      }
    } catch (_) {
      final courses = await _db.getCourses(user.id);
      try {
        _course = courses.firstWhere((c) => c.id == widget.courseId);
      } catch (_) {
        _course = null;
      }
      final allTasks = await _db.getTasks(user.id);
      _tasks = allTasks.where((t) => t.courseId == widget.courseId).toList();
      _tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      _upcoming = _tasks.take(5).toList();
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  double get _progress {
    final total = _tasks.isNotEmpty ? _tasks.length : (_course?.taskCount ?? 0);
    if (total == 0) return 0.0;
    final completed = _tasks.where((t) => t.isCompleted).length;
    return completed / total;
  }

  String _dateLabel(DateTime dt) => DateFormat.MMMd().format(dt);

  String _timeLabel(DateTime dt) => DateFormat.jm().format(dt);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_course == null) return const Scaffold(body: Center(child: Text('Course not found')));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        centerTitle: true,
        title: const Text('Course Details', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF1A1A2E)),
            onSelected: (value) {
              if (value == 'refresh') {
                _loadData();
              } else if (value == 'info') {
                _showMessage('Course actions are limited in this screen.');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              PopupMenuItem(value: 'info', child: Text('Info')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _course!.courseColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_courseIcon(_course!.icon), color: _course!.courseColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _course!.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 0.6,
                            color: _course!.courseColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _course!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Course Progress', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('${(_progress * 100).round()}%', style: TextStyle(color: _course!.courseColor, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7F1),
                        valueColor: AlwaysStoppedAnimation<Color>(_course!.courseColor),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _statTile('Total Tasks', '${_tasks.length}')),
                        Container(width: 1, height: 34, color: const Color(0xFFE5E7F1)),
                        Expanded(child: _statTile('Completed', '${_tasks.where((t) => t.isCompleted).length}', valueColor: const Color(0xFFF72585))),
                        Container(width: 1, height: 34, color: const Color(0xFFE5E7F1)),
                        Expanded(child: _statTile('Remaining', '${_tasks.where((t) => !t.isCompleted).length}')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Upcoming Tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  TextButton(onPressed: () => _showMessage('View all tasks from the calendar or home screen.'), child: const Text('View All')),
                ],
              ),
              const SizedBox(height: 8),
              if (_upcoming.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                  ),
                  child: Text('No upcoming tasks in this course yet.', style: TextStyle(color: Colors.grey.shade600)),
                )
              else
                ..._upcoming.map((task) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _course!.courseColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.assignment_outlined, color: _course!.courseColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                              const SizedBox(height: 4),
                              Text(
                                'Due ${_dateLabel(task.dueDate)} • ${_timeLabel(task.dueDate)}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (task.isCompleted)
                          const Icon(Icons.check_circle, color: Color(0xFF4CC9F0), size: 18)
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _priorityColor(task.priority).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              task.priority.toUpperCase(),
                              style: TextStyle(color: _priorityColor(task.priority), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 18),
              const Text('Instructor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 20, backgroundImage: NetworkImage('https://picsum.photos/200')),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dr. Sarah Jenkins', style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Office: Tue/Thu 3-5 PM', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showMessage('Email action is not wired yet.'),
                      icon: const Icon(Icons.email_outlined, color: Color(0xFF4361EE)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }

  Widget _statTile(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor ?? const Color(0xFF1A1A2E))),
      ],
    );
  }
}


