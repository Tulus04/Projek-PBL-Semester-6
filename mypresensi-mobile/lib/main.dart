// lib/main.dart
// Entry point MyPresensi Mobile — ProviderScope + MaterialApp.router.
// Menggunakan FlutterNativeSplash.preserve() agar native splash (background
// polos) tetap tampil sampai Flutter splash screen siap render.
// Register DioClient logout callback setelah ProviderScope siap.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'shared/widgets/app_shell.dart';

void main() async {
  // Preserve native splash — ditahan sampai FlutterNativeSplash.remove()
  // dipanggil di SplashScreen.initState()
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Inisialisasi Firebase SEBELUM runApp — dibutuhkan FCM.
  // Register background handler top-level (lihat fcm_service.dart).
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    // App tetap jalan walau Firebase gagal init (mis. google-services.json hilang).
    debugPrint('[FCM] Firebase init error: $e');
  }

  // Inisialisasi config — deteksi emulator/physical device, set baseUrl
  await AppConfig.initialize();

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Orientasi portrait only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: MyPresensiApp(),
    ),
  );
}

class MyPresensiApp extends ConsumerStatefulWidget {
  const MyPresensiApp({super.key});

  @override
  ConsumerState<MyPresensiApp> createState() => _MyPresensiAppState();
}

class _MyPresensiAppState extends ConsumerState<MyPresensiApp> {
  @override
  void initState() {
    super.initState();

    // Register logout callback ke DioClient.
    // Saat interceptor mendapati 401 dari non-login request,
    // otomatis trigger logout di auth provider.
    DioClient.setLogoutCallback(() async {
      ref.read(authProvider.notifier).logout();
    });

    // Register navigasi deep link FCM. Dipanggil saat user tap notif.
    // Catatan: '/notifications' BUKAN GoRoute — itu tab index 3 di AppShell.
    // Jadi map ke setTab(3) + go('/'). Route lain pakai context.go biasa.
    FcmService.setNavigationCallback((route) {
      final router = ref.read(routerProvider);
      if (route == '/notifications') {
        ref.read(currentTabProvider.notifier).setTab(3);
        router.go('/');
      } else {
        router.go(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MyPresensi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
