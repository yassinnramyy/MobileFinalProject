import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/home_screen.dart';
import '../screens/add_task_screen.dart';
import '../screens/task_detail_screen.dart';
import '../screens/courses_screen.dart';
import '../screens/add_course_screen.dart';
import '../screens/course_detail_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // Only redirect away from splash if trying to access protected routes
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = authProvider.isLoggedIn;
    final location = state.matchedLocation;

    // Never redirect away from splash or auth screens
    if (location == '/' || location == '/login' || location == '/signup') {
      return null;
    }

    // If trying to access protected screen without login → go to login
    if (!isLoggedIn) return '/login';

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/add-task',
      builder: (context, state) => const AddTaskScreen(),
    ),
    GoRoute(
      path: '/task/:id',
      builder: (context, state) {
        final taskId = state.pathParameters['id']!;
        return TaskDetailScreen(taskId: taskId);
      },
    ),
    GoRoute(
      path: '/courses',
      builder: (context, state) => const CoursesScreen(),
    ),
    GoRoute(
      path: '/course/:id',
      builder: (context, state) {
        final courseId = state.pathParameters['id']!;
        return CourseDetailScreen(courseId: courseId);
      },
    ),
    GoRoute(
      path: '/add-course',
      builder: (context, state) => const AddCourseScreen(),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);