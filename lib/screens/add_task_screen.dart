import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/task_provider.dart';
import '../models/course_model.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedCourseId;
  String _priority = 'medium';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

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
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a title')));
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    final due = _composeDateTime();
    final courses = context.read<TaskProvider>().courses;
    final course = courses.firstWhere(
        (c) => c.id == (_selectedCourseId ?? ''),
        orElse: () => Course(
            id: '', name: '', color: 0xFF4361EE, icon: 'book', userId: ''));

    await context.read<TaskProvider>().addTask(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          courseId: course.id,
          courseName: course.name,
          dueDate: due,
          priority: _priority,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<TaskProvider>().courses;
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
                      items: courses
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