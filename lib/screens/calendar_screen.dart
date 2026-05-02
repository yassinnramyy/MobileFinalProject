import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../core/connectivity_service.dart';
import '../data/local/database_helper.dart';
import '../models/task_model.dart';
import 'home_screen.dart'; // re-use shared bottom nav

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;
  final _connectivity = ConnectivityService();

  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<String, List<Task>> _tasksByDate = {}; // key = "yyyy-MM-dd"
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllTasks();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadAllTasks() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final online = await _connectivity.isOnline();
    List<Task> allTasks = [];

    if (online) {
      try {
        final snapshot = await _firestore
            .collection('tasks')
            .where('userId', isEqualTo: user.id)
            .get();
        allTasks = snapshot.docs.map((d) => _taskFromFirestore(d)).toList();
        for (final t in allTasks) {
          await _db.insertTask(t);
        }
      } catch (_) {
        allTasks = await _db.getTasks(user.id);
      }
    } else {
      allTasks = await _db.getTasks(user.id);
    }

    // Group tasks by date key
    final Map<String, List<Task>> grouped = {};
    for (final task in allTasks) {
      final key = _dateKey(task.dueDate);
      grouped.putIfAbsent(key, () => []).add(task);
    }

    setState(() {
      _tasksByDate = grouped;
      _isLoading = false;
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

  List<Task> get _selectedDayTasks =>
      _tasksByDate[_dateKey(_selectedDay)] ?? [];

  // Build the calendar grid
  List<DateTime?> _buildCalendarDays() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 0=Sun
    final days = <DateTime?>[];

    // Pad with nulls for days before month starts
    for (int i = 0; i < startWeekday; i++) {
      days.add(null);
    }
    for (int d = 1; d <= lastDay.day; d++) {
      days.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }
    return days;
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isSelected(DateTime d) =>
      d.year == _selectedDay.year &&
          d.month == _selectedDay.month &&
          d.day == _selectedDay.day;

  String _monthName(int m) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[m];
  }

  String _formatTaskTime(Task task) {
    final h = task.dueDate.hour;
    final m = task.dueDate.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour12:$m $period';
  }

  IconData _courseIcon(String courseName) {
    final lower = courseName.toLowerCase();
    if (lower.contains('math') || lower.contains('calculus')) {
      return Icons.functions;
    } else if (lower.contains('bio') || lower.contains('lab')) {
      return Icons.biotech;
    } else if (lower.contains('history')) {
      return Icons.menu_book;
    } else if (lower.contains('econ') || lower.contains('macro')) {
      return Icons.account_balance;
    } else if (lower.contains('cs') ||
        lower.contains('data') ||
        lower.contains('computer')) {
      return Icons.code;
    } else if (lower.contains('psych')) {
      return Icons.psychology;
    } else if (lower.contains('chem')) {
      return Icons.science;
    }
    return Icons.book_outlined;
  }

  Color _courseIconColor(String courseName) {
    final lower = courseName.toLowerCase();
    if (lower.contains('econ') || lower.contains('macro')) {
      return const Color(0xFF7B2D8B);
    } else if (lower.contains('bio') || lower.contains('lab')) {
      return const Color(0xFF0D9E8A);
    } else if (lower.contains('calculus') || lower.contains('quiz')) {
      return const Color(0xFFF72585);
    }
    return const Color(0xFF4361EE);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final name = user?.name.split(' ').first ?? 'User';
    final calDays = _buildCalendarDays();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadAllTasks,
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
                      const Expanded(
                        child: Text(
                          'Calendar',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E)),
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

              // ── Calendar Card ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Month navigation
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.chevron_left,
                                      color: Color(0xFF4361EE)),
                                  onPressed: () => setState(() {
                                    _focusedMonth = DateTime(
                                        _focusedMonth.year,
                                        _focusedMonth.month - 1);
                                  }),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.chevron_right,
                                      color: Color(0xFF4361EE)),
                                  onPressed: () => setState(() {
                                    _focusedMonth = DateTime(
                                        _focusedMonth.year,
                                        _focusedMonth.month + 1);
                                  }),
                                ),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Day-of-week headers
                        Row(
                          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                              .map((d) => Expanded(
                            child: Center(
                              child: Text(d,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color:
                                      Colors.grey.shade500)),
                            ),
                          ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),

                        // Calendar grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics:
                          const NeverScrollableScrollPhysics(),
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1,
                          ),
                          itemCount: calDays.length,
                          itemBuilder: (context, i) {
                            final day = calDays[i];
                            if (day == null) return const SizedBox();

                            final hasTask =
                                (_tasksByDate[_dateKey(day)] ?? [])
                                    .isNotEmpty;
                            final taskDots =
                                _tasksByDate[_dateKey(day)] ?? [];
                            final isSelected = _isSelected(day);
                            final isToday = _isToday(day);

                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedDay = day),
                              child: Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF4361EE)
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isToday || isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Colors.white
                                              : (isToday
                                              ? const Color(
                                              0xFF4361EE)
                                              : const Color(
                                              0xFF1A1A2E)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Task dots
                                  if (hasTask)
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: taskDots
                                          .take(3)
                                          .map((t) => Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets
                                            .symmetric(
                                            horizontal: 1),
                                        decoration: BoxDecoration(
                                          color:
                                          t.priorityColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ))
                                          .toList(),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Tasks for selected day ───────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tasks for ${_monthName(_selectedDay.month).substring(0, 3)} ${_selectedDay.day}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      if (_selectedDayTasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedDayTasks.length} Tasks',
                            style: const TextStyle(
                                color: Color(0xFF4361EE),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              _selectedDayTasks.isEmpty
                  ? SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.event_available,
                            size: 48,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('No tasks for this day',
                            style: TextStyle(
                                color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ),
              )
                  : SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final task = _selectedDayTasks[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 6),
                      child: _CalendarTaskCard(
                        task: task,
                        timeLabel: _formatTaskTime(task),
                        icon: _courseIcon(task.courseName),
                        iconColor:
                        _courseIconColor(task.courseName),
                        onTap: () =>
                            context.push('/task/${task.id}'),
                      ),
                    );
                  },
                  childCount: _selectedDayTasks.length,
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
          _loadAllTasks();
        },
        backgroundColor: const Color(0xFF4361EE),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}

// ──────────────────────────────────────────
// Calendar Task Card
// ──────────────────────────────────────────
class _CalendarTaskCard extends StatelessWidget {
  final Task task;
  final String timeLabel;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CalendarTaskCard({
    required this.task,
    required this.timeLabel,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E)),
                        ),
                      ),
                      // High priority dot
                      if (task.priority == 'high')
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: task.priorityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(task.courseName,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Text(
              timeLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: task.priority == 'high'
                    ? task.priorityColor
                    : const Color(0xFF4361EE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
