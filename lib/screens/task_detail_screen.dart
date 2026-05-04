import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../data/local/database_helper.dart';
import '../models/task_model.dart';
import '../core/connectivity_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;
  final _connectivity = ConnectivityService();

  Task? _task;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    final online = await _connectivity.isOnline();
    try {
      if (online) {
        final doc = await _firestore.collection('tasks').doc(widget.taskId).get();
        if (doc.exists) {
          final data = doc.data()!;
          _task = Task(
            id: doc.id,
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
      }
    } catch (_) {
      // fallback to local
    }

    if (_task == null) {
      // Try local database
      final userId = user.id;
      final list = await _db.getTasks(userId);
      try {
        _task = list.firstWhere((t) => t.id == widget.taskId);
      } catch (_) {
        _task = null;
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _toggleComplete() async {
    if (_task == null) return;
    final newStatus = !_task!.isCompleted;
    await _db.updateTaskStatus(_task!.id, newStatus);
    final online = await _connectivity.isOnline();
    if (online) {
      try {
        await _firestore.collection('tasks').doc(_task!.id).update({'isCompleted': newStatus});
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _task!.isCompleted = newStatus);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_task == null) return const Scaffold(body: Center(child: Text('Task not found')));

    final dt = _task!.dueDate;
    final dateStr = DateFormat.yMMMMd().format(dt);
    final timeStr = DateFormat.jm().format(dt);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        title: const Text('Task Detail', style: TextStyle(color: Color(0xFF1A1A2E))),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.edit, color: Colors.grey)),
          IconButton(onPressed: () async {
            await _db.deleteTask(_task!.id);
            final online = await _connectivity.isOnline();
            if (online) {
              try { await _firestore.collection('tasks').doc(_task!.id).delete(); } catch (_) {}
            }
            if (!context.mounted) return;
            Navigator.of(context).pop(true);
          }, icon: const Icon(Icons.delete, color: Colors.red)),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_task!.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Chip(label: Text(_task!.isCompleted ? 'Completed' : 'In Progress'), backgroundColor: _task!.isCompleted ? const Color(0xFF4CC9F0) : const Color(0xFFEAF0FF)),
                const SizedBox(width: 8),
                Chip(label: Text('${_task!.priority.toUpperCase()} PRIORITY'), backgroundColor: _task!.priority == 'high' ? const Color(0xFFF72585) : (_task!.priority == 'medium' ? const Color(0xFFFFF1E6) : const Color(0xFFEAF0FF))),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF4361EE).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.school_outlined, color: Color(0xFF4361EE))),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_task!.courseName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Due: $dateStr • $timeStr', style: TextStyle(color: Colors.grey.shade600)),
                    ])
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.error_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Urgency', style: TextStyle(fontWeight: FontWeight.w600))),
                  ])
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]), child: Text(_task!.description.isEmpty ? 'No description provided.' : _task!.description)),
              const SizedBox(height: 16),
              const Text('Attachments', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Row(children: const [Icon(Icons.picture_as_pdf, color: Colors.blue), SizedBox(width: 8), Text('Syllabus.pdf')]))
              ]),
              const SizedBox(height: 12),
              Container(height: 140, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: const DecorationImage(image: NetworkImage('https://picsum.photos/800/300'), fit: BoxFit.cover))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _toggleComplete,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4361EE), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_task!.isCompleted ? Icons.undo : Icons.check, color: Colors.white), const SizedBox(width: 8), Text(_task!.isCompleted ? 'Mark as Incomplete' : 'Mark as Complete')]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}