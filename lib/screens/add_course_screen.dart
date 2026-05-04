import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../data/local/database_helper.dart';
import '../models/course_model.dart';
import '../core/connectivity_service.dart';
import 'home_screen.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _nameController = TextEditingController();
  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;
  final _connectivity = ConnectivityService();

  final _colors = [
    const Color(0xFF4361EE),
    const Color(0xFFE63946),
    const Color(0xFF4CC9F0),
    const Color(0xFFFFB703),
    const Color(0xFF9B5DE5),
    const Color(0xFFEF476F),
  ];

  final _icons = ['calculus', 'chemistry', 'globe', 'palette', 'code', 'music'];

  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;
  bool _isSaving = false;
  List<Course> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final online = await _connectivity.isOnline();
    try {
      if (online) {
        final snap = await _firestore
            .collection('courses')
            .where('userId', isEqualTo: user.id)
            .orderBy('name')
            .get();
        final list = snap.docs
            .map((d) => Course.fromMap({
                  'id': d.id,
                  'name': d.data()['name'] ?? '',
                  'color': d.data()['color'] ?? 0xFF4361EE,
                  'icon': d.data()['icon'] ?? 'book',
                  'userId': d.data()['userId'] ?? '',
                  'taskCount': d.data()['taskCount'] ?? 0,
                }))
            .toList();
        setState(() => _recent = list);
      } else {
        final local = await _db.getCourses(user.id);
        setState(() => _recent = local);
      }
    } catch (_) {
      final local = await _db.getCourses(user.id);
      setState(() => _recent = local);
    }
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'calculus':
        return Icons.functions;
      case 'chemistry':
        return Icons.science;
      case 'globe':
        return Icons.public;
      case 'palette':
        return Icons.palette;
      case 'code':
        return Icons.code;
      case 'music':
        return Icons.music_note;
      default:
        return Icons.book_outlined;
    }
  }

  Future<void> _saveCourse() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter course name')));
      return;
    }
    if (!mounted) return;
    setState(() => _isSaving = true);
    final id = const Uuid().v4();
    final course = Course(
      id: id,
      name: _nameController.text.trim(),
      color: _colors[_selectedColorIndex].toARGB32(),
      icon: _icons[_selectedIconIndex],
      userId: user.id,
    );

    await _db.insertCourse(course);
    final online = await _connectivity.isOnline();
    if (online) {
      try {
        await _firestore.collection('courses').doc(id).set({
          'name': course.name,
          'color': course.color,
          'icon': course.icon,
          'userId': course.userId,
          'taskCount': course.taskCount,
        });
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4361EE)),
        title: const Text('New Course', style: TextStyle(color: Color(0xFF1A1A2E))),
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
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('COURSE NAME', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Advanced Calculus',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: const Color(0xFFF6F7FB),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('COURSE COLOR', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(_colors.length, (i) {
                        final c = _colors[i];
                        final selected = i == _selectedColorIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColorIndex = i),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: selected ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    const Text('ICON SELECTION', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(_icons.length, (i) {
                        final ico = _icons[i];
                        final selected = i == _selectedIconIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedIconIndex = i),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFFEAF0FF) : const Color(0xFFF6F7FB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_iconFor(ico), color: _colors[_selectedColorIndex]),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Recent Courses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Column(
                children: _recent.map((c) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: c.courseColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                          child: Icon(_iconFor(c.icon), color: c.courseColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        PopupMenuButton<int>(
                          itemBuilder: (_) => [const PopupMenuItem(value: 0, child: Text('Delete'))],
                          onSelected: (v) async {
                            if (v == 0) {
                              await _db.deleteCourse(c.id);
                              final online = await _connectivity.isOnline();
                              if (online) {
                                try {
                                  await _firestore.collection('courses').doc(c.id).delete();
                                } catch (_) {}
                              }
                              _loadRecent();
                            }
                          },
                        )
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveCourse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4361EE),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save),
                    const SizedBox(width: 8),
                    Text(_isSaving ? 'Saving...' : 'Save Course'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }
}