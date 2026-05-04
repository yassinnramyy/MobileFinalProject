import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../data/local/database_helper.dart';
import '../models/task_model.dart';
import '../models/course_model.dart';
import '../core/connectivity_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;
  final _connectivity = ConnectivityService();

  List<Course> _courses = [];
  String? _selectedCourseId;
  String _priority = 'medium';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final online = await _connectivity.isOnline();
    try {
      if (online) {
        final snap = await _firestore
            .collection('courses')
            .where('userId', isEqualTo: user.id)
            .get();
        final docs = snap.docs
            .map((d) => Course(
                  id: d.id,
                  name: d.data()['name'] ?? '',
                  color: d.data()['color'] ?? 0xFF4361EE,
                  icon: d.data()['icon'] ?? 'book',
                  userId: d.data()['userId'] ?? '',
                  taskCount: d.data()['taskCount'] ?? 0,
                ))
            .toList();
        setState(() => _courses = docs);
      } else {
        final local = await _db.getCourses(user.id);
        setState(() => _courses = local);
      }
    } catch (_) {
      final local = await _db.getCourses(user.id);
      setState(() => _courses = local);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  DateTime _composeDateTime() {
    final date = _selectedDate ?? DateTime.now();
    final time = _selectedTime ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveTask() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a title')));
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    final id = const Uuid().v4();
    final due = _composeDateTime();
    final course = _courses.firstWhere(
        (c) => c.id == (_selectedCourseId ?? ''),
        orElse: () => Course(
            id: '', name: '', color: 0xFF4361EE, icon: 'book', userId: ''));

    final task = Task(
      id: id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      courseId: course.id,
      courseName: course.name,
      dueDate: due,
      priority: _priority,
      userId: user.id,
    );

    // Save locally
    await _db.insertTask(task);

    // Save to Firestore if online
    final online = await _connectivity.isOnline();
    if (online) {
      try {
        await _firestore.collection('tasks').doc(id).set({
          'title': task.title,
          'description': task.description,
          'courseId': task.courseId,
          'courseName': task.courseName,
          'dueDate': Timestamp.fromDate(task.dueDate),
          'priority': task.priority,
          'isCompleted': task.isCompleted,
          'userId': task.userId,
        });
      } catch (_) {
        // ignore — we already saved locally
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _selectedDate == null
        ? 'mm/dd/yyyy'
        : DateFormat.yMMMd().format(_selectedDate!);
    final timeLabel = _selectedTime == null
        ? '--:-- --'
        : _selectedTime!.format(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4361EE)),
        title: const Text('New Task', style: TextStyle(color: Color(0xFF4361EE))),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TASK TITLE', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Final Research Paper',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFFF6F7FB),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('DESCRIPTION', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Outline the main objectives and required resources...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFFF6F7FB),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('COURSE', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCourseId,
                      items: _courses
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name.isEmpty ? 'Unnamed' : c.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCourseId = v),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFFF6F7FB),
                      ),
                      hint: const Text('Select a course'),
                    ),
                    const SizedBox(height: 12),
                    const Text('PRIORITY LEVEL', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _priorityButton('low', 'Low'),
                        const SizedBox(width: 8),
                        _priorityButton('medium', 'Medium'),
                        const SizedBox(width: 8),
                        _priorityButton('high', 'High'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DUE DATE', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color(0xFFF6F7FB),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(dateLabel),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DUE TIME', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color(0xFFF6F7FB),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(timeLabel),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4361EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Organizing your tasks reduces cognitive load by up to 20%. Stay focused, stay disciplined.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4361EE),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(_isSaving ? 'Saving...' : 'Save Task'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priorityButton(String value, String label) {
    final selected = _priority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF0FF) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? const Color(0xFF4361EE) : Colors.grey.shade300),
          ),
          child: Center(
              child: Text(label, style: TextStyle(color: selected ? const Color(0xFF4361EE) : Colors.grey.shade700))),
        ),
      ),
    );
  }
}