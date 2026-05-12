import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initProvider());
  }

  Future<void> _initProvider() async {
    if (_didInit) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    _didInit = true;
    await context.read<TaskProvider>().init(user.id);
  }

  List<Task> _todayTasks(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return tasks
        .where((t) =>
            t.dueDate.isAfter(today.subtract(const Duration(seconds: 1))) &&
            t.dueDate.isBefore(tomorrow))
        .toList();
  }

  Future<void> _toggleTask(Task task) async {
    await context.read<TaskProvider>().toggleTaskCompletion(task.id);
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
    final taskProvider = context.watch<TaskProvider>();
    final todayTasks = _todayTasks(taskProvider.tasks);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: taskProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => context.read<TaskProvider>().loadTasks(),
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
                        child: StreamBuilder<Map<String, int>>(
                          stream: taskProvider.listenToStats(),
                          builder: (context, snapshot) {
                            final stats = snapshot.data ?? {};
                            final total = stats['total'] ?? taskProvider.totalTasks;
                            final dueToday = stats['dueToday'] ?? taskProvider.dueTodayTasks;
                            final completed = stats['completed'] ?? taskProvider.completedTasks;
                            return Row(
                              children: [
                                _StatCard(
                                    label: 'Total\nTasks',
                                    value: total,
                                    color: const Color(0xFF4361EE)),
                                const SizedBox(width: 12),
                                _StatCard(
                                    label: 'Due Today',
                                    value: dueToday,
                                    color: const Color(0xFFF72585)),
                                const SizedBox(width: 12),
                                _StatCard(
                                    label: 'Completed',
                                    value: completed,
                                    color: const Color(0xFF4CC9F0)),
                              ],
                            );
                          },
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
                    todayTasks.isEmpty
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
                                final task = todayTasks[i];
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
                              childCount: todayTasks.length,
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
          await context.read<TaskProvider>().loadTasks();
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
