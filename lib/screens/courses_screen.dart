import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../core/connectivity_service.dart';
import '../data/local/database_helper.dart';
import '../models/course_model.dart';
import 'home_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;
  final _connectivity = ConnectivityService();

  List<Course> _courses = [];
  bool _isLoading = true;
  String _semester = 'Fall 2024'; // Could be fetched from settings

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final online = await _connectivity.isOnline();

    if (online) {
      try {
        final snapshot = await _firestore
            .collection('courses')
            .where('userId', isEqualTo: user.id)
            .get();

        final courses = <Course>[];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final course = Course(
            id: doc.id,
            name: data['name'] ?? '',
            color: data['color'] ?? 0xFF4361EE,
            icon: data['icon'] ?? 'book',
            userId: data['userId'] ?? '',
            taskCount: data['taskCount'] ?? 0,
          );

          // Get task count from tasks collection
          final tasksSnap = await _firestore
              .collection('tasks')
              .where('courseId', isEqualTo: doc.id)
              .where('userId', isEqualTo: user.id)
              .get();
          course.taskCount = tasksSnap.docs.length;

          courses.add(course);
          await _db.insertCourse(course);
        }

        setState(() {
          _courses = courses;
          _isLoading = false;
        });
      } catch (_) {
        await _loadFromLocal(user.id);
      }
    } else {
      await _loadFromLocal(user.id);
    }
  }

  Future<void> _loadFromLocal(String userId) async {
    final courses = await _db.getCourses(userId);
    setState(() {
      _courses = courses;
      _isLoading = false;
    });
  }

  Future<void> _deleteCourse(Course course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text(
            'Delete "${course.name}"? All associated tasks will remain.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFF72585)))),
        ],
      ),
    );

    if (confirm != true) return;

    final online = await _connectivity.isOnline();

    // Delete from local
    await _db.deleteCourse(course.id);

    // Delete from Firestore if online
    if (online) {
      await _firestore.collection('courses').doc(course.id).delete();
    }

    setState(() => _courses.removeWhere((c) => c.id == course.id));
  }

  // Map icon string → IconData
  IconData _iconData(String icon) {
    switch (icon) {
      case 'math':
      case 'calculus':
        return Icons.functions;
      case 'science':
      case 'chemistry':
        return Icons.science;
      case 'biology':
        return Icons.biotech;
      case 'history':
        return Icons.menu_book;
      case 'economics':
        return Icons.account_balance;
      case 'cs':
      case 'code':
        return Icons.code;
      case 'psych':
        return Icons.psychology;
      default:
        return Icons.book_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final name = user?.name.split(' ').first ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadCourses,
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu,
                            color: Color(0xFF4361EE)),
                        onPressed: () {},
                      ),
                      const Expanded(
                        child: Text(
                          'My Courses',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E)),
                        ),
                      ),
                      // Add course button
                      IconButton(
                        icon: const Icon(Icons.add,
                            color: Color(0xFF4361EE), size: 28),
                        onPressed: () async {
                          await context.push('/add-course');
                          _loadCourses();
                        },
                      ),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF4361EE),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Semester Info ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Semesters',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_semester • ${_courses.length} Courses Total',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Courses Grid ─────────────────────────────
              _courses.isEmpty
                  ? SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.school_outlined,
                            size: 64,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No courses yet.\nTap + to add your first course!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              )
                  : SliverPadding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.0,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      final course = _courses[i];
                      return _CourseCard(
                        course: course,
                        icon: _iconData(course.icon),
                        onTap: () {
                          // Navigate to course detail / tasks filtered by course
                          // context.push('/course/${course.id}');
                        },
                        onLongPress: () => _deleteCourse(course),
                      );
                    },
                    childCount: _courses.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }
}

// ──────────────────────────────────────────
// Course Card Widget
// ──────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final Course course;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CourseCard({
    required this.course,
    required this.icon,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = course.courseColor;
    final taskLabel = course.taskCount == 1 ? '1 TASK' : '${course.taskCount} TASKS';
    final taskLabelColor =
    course.taskCount == 0 ? Colors.grey.shade400 : color;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              course.name,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              taskLabel,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: taskLabelColor,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
