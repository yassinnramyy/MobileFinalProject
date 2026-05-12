import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import 'home_screen.dart'; // re-use shared bottom nav

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<Task>> _groupTasks(List<Task> tasks) {
    final events = LinkedHashMap<DateTime, List<Task>>(
      equals: isSameDay,
      hashCode: _hashCode,
    );
    for (final task in tasks) {
      final day = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      events.putIfAbsent(day, () => []).add(task);
    }
    return events;
  }

  int _hashCode(DateTime key) => key.day * 1000000 + key.month * 10000 + key.year;

  List<Task> _getEventsForDay(DateTime day, Map<DateTime, List<Task>> events) {
    return events[day] ?? [];
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
    final taskProvider = context.watch<TaskProvider>();
    final events = _groupTasks(taskProvider.tasks);
    final selectedDay = _selectedDay ?? DateTime.now();
    final selectedTasks = _getEventsForDay(selectedDay, events);

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
                            const Expanded(
                              child: Text(
                                'Calendar',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A2E)),
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
                          padding: const EdgeInsets.all(16),
                          child: TableCalendar<Task>(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2035, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            calendarFormat: CalendarFormat.month,
                            eventLoader: (day) => _getEventsForDay(day, events),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            calendarStyle: CalendarStyle(
                              todayDecoration: BoxDecoration(
                                color: const Color(0xFF4361EE).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: const BoxDecoration(
                                color: Color(0xFF4361EE),
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: const BoxDecoration(
                                color: Color(0xFFF72585),
                                shape: BoxShape.circle,
                              ),
                              markersMaxCount: 3,
                            ),
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                            ),
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
                              'Tasks for ${selectedDay.month}/${selectedDay.day}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (selectedTasks.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${selectedTasks.length} Tasks',
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

                    selectedTasks.isEmpty
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
                                final task = selectedTasks[i];
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
                              childCount: selectedTasks.length,
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
