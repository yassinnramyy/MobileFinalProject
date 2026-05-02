import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../core/connectivity_service.dart';
import '../data/local/database_helper.dart';
import '../models/task_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;
  final _connectivity = ConnectivityService();

  List<Task> _todayTasks = [];
  int _totalTasks = 0;
  int _completedTasks = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final online = await _connectivity.isOnline();

    if (online) {
      try {
        // Fetch all tasks from Firestore
        final snapshot = await _firestore
            .collection('tasks')
            .where('userId', isEqualTo: user.id)
            .get();

        final allTasks =
        snapshot.docs.map((d) => _taskFromFirestore(d)).toList();

        // Sync to local
        for (final t in allTasks) {
          await _db.insertTask(t);
        }

        _processTasks(allTasks);
      } catch (_) {
        await _loadFromLocal(user.id);
      }
    } else {
      await _loadFromLocal(user.id);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadFromLocal(String userId) async {
    final allTasks = await _db.getTasks(userId);
    _processTasks(allTasks);
  }

  void _processTasks(List<Task> allTasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todayTasks = allTasks
        .where((t) =>
    t.dueDate.isAfter(today.subtract(const Duration(seconds: 1))) &&
        t.dueDate.isBefore(tomorrow))
        .toList();

    setState(() {
      _todayTasks = todayTasks;
      _totalTasks = allTasks.length;
      _completedTasks = allTasks.where((t) => t.isCompleted).length;
    });
  }

  Task _taskFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
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

  Future<void> _toggleTask(Task task) async {
    final newStatus = !task.isCompleted;
    final online = await _connectivity.isOnline();

    // Update local
    await _db.updateTaskStatus(task.id, newStatus);

    // Update Firestore if online
    if (online) {
      await _firestore
          .collection('tasks')
          .doc(task.id)
          .update({'isCompleted': newStatus});
    }

    setState(() {
      task.isCompleted = newStatus;
      _completedTasks = _todayTasks.where((t) => t.isCompleted).length;
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatDueTime(Task task) {
    final now = DateTime.now();
    final diff = task.dueDate.difference(now);
    if (task.isCompleted) return 'Completed';
    if (diff.isNegative) return 'Overdue';
    if (diff.inHours < 1) return 'Due in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Due in ${diff.inHours}h';
    final h = task.dueDate.hour;
    final m = task.dueDate.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour12:$m $period';
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
          onRefresh: _loadTasks,
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
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${_greeting()}, $name 👋',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4361EE),
                          ),
                        ),
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

              // ── Stats Row ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _StatCard(
                          label: 'Total\nTasks',
                          value: _totalTasks,
                          color: const Color(0xFF4361EE)),
                      const SizedBox(width: 12),
                      _StatCard(
                          label: 'Due Today',
                          value: _todayTasks
                              .where((t) => !t.isCompleted)
                              .length,
                          color: const Color(0xFFF72585)),
                      const SizedBox(width: 12),
                      _StatCard(
                          label: 'Completed',
                          value: _completedTasks,
                          color: const Color(0xFF4CC9F0)),
                    ],
                  ),
                ),
              ),

              // ── Today's Tasks Header ─────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Today's Tasks",
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => context.push('/calendar'),
                        child: const Text('View All',
                            style: TextStyle(color: Color(0xFF4361EE))),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Task List ────────────────────────────────
              _todayTasks.isEmpty
                  ? SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No tasks for today!',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              )
                  : SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final task = _todayTasks[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 6),
                      child: _TaskCard(
                        task: task,
                        dueLabel: _formatDueTime(task),
                        onToggle: () => _toggleTask(task),
                        onTap: () =>
                            context.push('/task/${task.id}'),
                      ),
                    );
                  },
                  childCount: _todayTasks.length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/add-task');
          _loadTasks();
        },
        backgroundColor: const Color(0xFF4361EE),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}

// ──────────────────────────────────────────
// Stat Card Widget
// ──────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3)),
            const SizedBox(height: 8),
            Text('$value',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Task Card Widget
// ──────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final Task task;
  final String dueLabel;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.dueLabel,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = task.priorityColor;
    final isCompleted = task.isCompleted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            // Priority indicator bar
            Container(
              width: 5,
              height: 90,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF4CC9F0) : priorityColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color:
                        isCompleted ? Colors.grey : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(task.courseName,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          isCompleted
                              ? Icons.check_circle
                              : Icons.access_time,
                          size: 14,
                          color: isCompleted
                              ? const Color(0xFF4CC9F0)
                              : (dueLabel.contains('h') &&
                              !dueLabel.contains('Due in')
                              ? Colors.grey
                              : priorityColor),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dueLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isCompleted
                                ? const Color(0xFF4CC9F0)
                                : (dueLabel.startsWith('Due in')
                                ? priorityColor
                                : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Checkbox
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF4361EE)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF4361EE)
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Shared Bottom Navigation Bar
// ──────────────────────────────────────────
class BottomNav extends StatelessWidget {
  final int currentIndex;
  const BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: const Color(0xFF4361EE),
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (i) {
        switch (i) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/calendar');
            break;
          case 2:
            context.go('/courses');
            break;
          case 3:
            context.go('/profile');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
        BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month), label: 'CALENDAR'),
        BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined), label: 'COURSES'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: 'PROFILE'),
      ],
    );
  }
}
