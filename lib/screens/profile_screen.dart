import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/auth_provider.dart';
import '../core/connectivity_service.dart';
import '../data/local/database_helper.dart';
import '../models/task_model.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;
  final _connectivity = ConnectivityService();

  int _totalTasks = 0;
  int _completedTasks = 0;
  int _courses = 0;

  bool _isLoading = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // 🟢 Load stats (tasks + courses)
  Future<void> _loadStats() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final online = await _connectivity.isOnline();

    try {
      if (online) {
        // 🔹 Tasks
        final taskSnap = await _firestore
            .collection('tasks')
            .where('userId', isEqualTo: user.id)
            .get();

        final tasks =
        taskSnap.docs.map((d) => _taskFromFirestore(d)).toList();

        // 🔹 Courses
        final courseSnap = await _firestore
            .collection('courses')
            .where('userId', isEqualTo: user.id)
            .get();

        setState(() {
          _totalTasks = tasks.length;
          _completedTasks =
              tasks.where((t) => t.isCompleted).length;
          _courses = courseSnap.docs.length;
        });
      } else {
        // 🔹 Local fallback
        final tasks = await _db.getTasks(user.id);
        final courses = await _db.getCourses(user.id);

        setState(() {
          _totalTasks = tasks.length;
          _completedTasks =
              tasks.where((t) => t.isCompleted).length;
          _courses = courses.length;
        });
      }
    } catch (_) {}

    setState(() => _isLoading = false);
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

  // 🟢 Logout
  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    final name = user?.name ?? "User";
    final email = user?.email ?? "email@example.com";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            children: [
              // 🔵 HEADER
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF4361EE),
                      Color(0xFF3A0CA3)
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // Avatar
                    Stack(
                      children: [
                        const CircleAvatar(
                          radius: 45,
                          backgroundImage:
                          AssetImage('assets/avatar.png'),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.edit, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),

                    Text(
                      email,
                      style: const TextStyle(
                          color: Colors.white70),
                    ),

                    const SizedBox(height: 20),

                    // 🔢 STATS
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                      children: [
                        _statBox(_totalTasks, "Tasks"),
                        _statBox(_completedTasks, "Completed"),
                        _statBox(_courses, "Courses"),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ⚙️ SETTINGS
              _tile(Icons.person, "Edit Profile",
                      () => context.push('/edit-profile')),

              _tile(Icons.notifications, "Notifications", () {}),

              SwitchListTile(
                title: const Text("Dark Mode"),
                value: _darkMode,
                onChanged: (v) {
                  setState(() => _darkMode = v);
                },
              ),

              _tile(Icons.info, "About App", () {}),

              const SizedBox(height: 20),

              // 🔴 LOGOUT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("Logout"),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  // 🔹 Stat box
  Widget _statBox(int value, String label) {
    return Column(
      children: [
        Text('$value',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label,
            style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  // 🔹 Setting tile
  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4361EE)),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}