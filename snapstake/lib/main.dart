import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_colors.dart';
import 'controllers/auth_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/betting_controller.dart';
import 'controllers/moments_controller.dart';
import 'pages/splash_screen.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/create_moment_page.dart';
import 'pages/camera_recording_page.dart';
import 'pages/moment_setup_page.dart';
import 'pages/moment_page.dart';
import 'pages/profile_page.dart';
import 'services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String supabaseUrl = "https://hveihxobdippfydfqgti.supabase.co";
  String supabaseAnonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh2ZWloeG9iZGlwcGZ5ZGZxZ3RpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyMDk5NDcsImV4cCI6MjA4MDc4NTk0N30.4s6872bZXqZxscPiz_MmVdraN10qVqvTvNb4yr0fP8Q";
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // Initialize Controllers
  Get.put(AuthController());
  Get.put(NavigationController());
  Get.put(BettingController());
  Get.put(MomentsController());
  Get.put(DeepLinkService(), permanent: true);
  await Get.find<DeepLinkService>().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SnapStake',
      routingCallback: (_) {
        if (Get.isRegistered<DeepLinkService>()) {
          Get.find<DeepLinkService>().tryNavigatePendingMoment();
        }
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/splash',
      getPages: [
        GetPage(name: '/splash', page: () => const SplashScreen()),
        GetPage(name: '/login', page: () => const LoginPage()),
        GetPage(name: '/home', page: () => const HomePage()),
        GetPage(name: '/create', page: () => const CreateMomentPage()),
        GetPage(name: '/camera', page: () => const CameraRecordingPage()),
        GetPage(
          name: '/moment-setup',
          page: () => MomentSetupPage(videoFile: Get.arguments['videoFile']),
        ),
        GetPage(
          name: '/moment',
          page: () => MomentPage(momentId: Get.arguments['momentId']),
        ),
        GetPage(name: '/profile', page: () => const ProfilePage()),
      ],
    );
  }
}
