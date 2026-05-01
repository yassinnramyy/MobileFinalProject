import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/task_model.dart';
import '../../models/course_model.dart';
import '../../models/user_model.dart';

class DatabaseHelper {
  // Singleton pattern — only one instance of this class exists in the whole app
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  // Getter — creates the database if it doesn't exist yet
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  // Initialize the database file
  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'campus_task.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // Create all tables when database is first created
  Future _createDB(Database db, int version) async {
    // Users table — for offline login
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        password TEXT NOT NULL
      )
    ''');

    // Courses table
    await db.execute('''
      CREATE TABLE courses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        icon TEXT NOT NULL,
        userId TEXT NOT NULL,
        taskCount INTEGER DEFAULT 0
      )
    ''');

    // Tasks table
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        courseId TEXT NOT NULL,
        courseName TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        priority TEXT NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        userId TEXT NOT NULL
      )
    ''');
  }

  // =====================
  // USER OPERATIONS
  // =====================

  // Save user locally (called after signup)
  Future<void> insertUser(UserModel user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get user by email and password (for offline login)
  Future<UserModel?> getUser(String email, String password) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (result.isEmpty) return null;
    return UserModel.fromMap(result.first);
  }

  // =====================
  // TASK OPERATIONS
  // =====================

  // Save a task locally
  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all tasks for a specific user
  Future<List<Task>> getTasks(String userId) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'dueDate ASC', // Nearest deadline first
    );
    return result.map((map) => Task.fromMap(map)).toList();
  }

  // Get tasks due today
  Future<List<Task>> getTasksForToday(String userId) async {
    final db = await database;
    final today = DateTime.now();
    final todayStr = DateTime(today.year, today.month, today.day)
        .toIso8601String();
    final tomorrowStr = DateTime(today.year, today.month, today.day + 1)
        .toIso8601String();
    final result = await db.query(
      'tasks',
      where: 'userId = ? AND dueDate >= ? AND dueDate < ?',
      whereArgs: [userId, todayStr, tomorrowStr],
    );
    return result.map((map) => Task.fromMap(map)).toList();
  }

  // Update task completion status
  Future<void> updateTaskStatus(String taskId, bool isCompleted) async {
    final db = await database;
    await db.update(
      'tasks',
      {'isCompleted': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  // =====================
  // COURSE OPERATIONS
  // =====================

  // Save a course locally
  Future<void> insertCourse(Course course) async {
    final db = await database;
    await db.insert(
      'courses',
      course.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all courses for a specific user
  Future<List<Course>> getCourses(String userId) async {
    final db = await database;
    final result = await db.query(
      'courses',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    return result.map((map) => Course.fromMap(map)).toList();
  }

  // Delete a course
  Future<void> deleteCourse(String courseId) async {
    final db = await database;
    await db.delete(
      'courses',
      where: 'id = ?',
      whereArgs: [courseId],
    );
  }
}