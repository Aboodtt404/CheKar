import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/capture_screen.dart';
import '../screens/obd_scan_screen.dart';
import '../screens/processing_screen.dart';
import '../screens/report_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isAuth = ref.watch(isAuthenticatedProvider);
  return GoRouter(
    initialLocation: isAuth ? '/home' : '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/capture/:mode', builder: (context, state) => CaptureScreen(mode: state.pathParameters['mode'] ?? 'quick')),
      GoRoute(path: '/obd/:id', builder: (context, state) => ObdScanScreen(inspectionId: state.pathParameters['id']!)),
      GoRoute(path: '/obd-standalone', builder: (context, state) => const ObdScanScreen(inspectionId: '')),
      GoRoute(path: '/processing/:id', builder: (context, state) => ProcessingScreen(inspectionId: state.pathParameters['id']!)),
      GoRoute(path: '/report/:id', builder: (context, state) => ReportScreen(inspectionId: state.pathParameters['id']!)),
    ],
  );
});
