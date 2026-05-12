import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../data/remote/realtime_database_service.dart';
import '../models/task_model.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _realtimeDb = RealtimeDatabaseService();

  Task? _findTask(List<Task> tasks) {
    try {
      return tasks.firstWhere((t) => t.id == widget.taskId);
    } catch (_) {
      return null;
    }
  }

  Stream<bool> _completionStream(String? userId) {
    if (userId == null) return const Stream<bool>.empty();
    return _realtimeDb.listenToTaskCompletion(userId, widget.taskId);
  }

  Future<void> _toggleComplete() async {
    await context.read<TaskProvider>().toggleTaskCompletion(widget.taskId);
  }

  Future<void> _deleteTask() async {
    await context.read<TaskProvider>().deleteTask(widget.taskId);
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().currentUser?.id;
    final taskProvider = context.watch<TaskProvider>();
    final task = _findTask(taskProvider.tasks);

    if (taskProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (task == null) {
      return const Scaffold(body: Center(child: Text('Task not found')));
    }

    final dt = task.dueDate;
    final dateStr = DateFormat.yMMMMd().format(dt);
    final timeStr = DateFormat.jm().format(dt);

    return StreamBuilder<bool>(
      stream: _completionStream(userId),
      builder: (context, snapshot) {
        final isCompleted = snapshot.data ?? task.isCompleted;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
            title: const Text('Task Detail', style: TextStyle(color: Color(0xFF1A1A2E))),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.edit, color: Colors.grey)),
              IconButton(onPressed: _deleteTask, icon: const Icon(Icons.delete, color: Colors.red)),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Chip(label: Text(isCompleted ? 'Completed' : 'In Progress'), backgroundColor: isCompleted ? const Color(0xFF4CC9F0) : const Color(0xFFEAF0FF)),
                    const SizedBox(width: 8),
                    Chip(label: Text('${task.priority.toUpperCase()} PRIORITY'), backgroundColor: task.priority == 'high' ? const Color(0xFFF72585) : (task.priority == 'medium' ? const Color(0xFFFFF1E6) : const Color(0xFFEAF0FF))),
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
                          Text(task.courseName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Due: $dateStr • $timeStr', style: TextStyle(color: Colors.grey.shade600)),
                        ])
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.error_outline, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Urgency', style: TextStyle(fontWeight: FontWeight.w600))),
                      ])
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]), child: Text(task.description.isEmpty ? 'No description provided.' : task.description)),
                  const SizedBox(height: 16),
                  const Text('Attachments', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.picture_as_pdf, color: Colors.blue), SizedBox(width: 8), Text('Syllabus.pdf')]))
                  ]),
                  const SizedBox(height: 12),
                  Container(height: 140, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: const DecorationImage(image: NetworkImage('https://picsum.photos/800/300'), fit: BoxFit.cover))),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _toggleComplete,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4361EE), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isCompleted ? Icons.undo : Icons.check, color: Colors.white), const SizedBox(width: 8), Text(isCompleted ? 'Mark as Incomplete' : 'Mark as Complete')]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
