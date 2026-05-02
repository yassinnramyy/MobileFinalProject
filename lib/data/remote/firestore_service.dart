import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task_model.dart';
import '../../models/course_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // =====================
  // TASK OPERATIONS
  // =====================

  // Save task to Firestore
  Future<void> addTask(Task task) async {
    await _db.collection('tasks').doc(task.id).set(task.toMap());
  }

  // Get all tasks for a user
  Stream<List<Task>> getTasks(String userId) {
    return _db
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Task.fromMap(doc.data())).toList());
  }

  // Update task
  Future<void> updateTask(Task task) async {
    await _db.collection('tasks').doc(task.id).update(task.toMap());
  }

  // Delete task
  Future<void> deleteTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).delete();
  }

  // =====================
  // COURSE OPERATIONS
  // =====================

  // Save course to Firestore
  Future<void> addCourse(Course course) async {
    await _db.collection('courses').doc(course.id).set(course.toMap());
  }

  // Get all courses for a user
  Stream<List<Course>> getCourses(String userId) {
    return _db
        .collection('courses')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Course.fromMap(doc.data())).toList());
  }

  // Delete course
  Future<void> deleteCourse(String courseId) async {
    await _db.collection('courses').doc(courseId).delete();
  }
}