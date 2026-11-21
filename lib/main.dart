import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/compact_ui_theme.dart';
import 'firebase_options.dart';

class SpotShareScrollBehavior extends MaterialScrollBehavior {
  const SpotShareScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[SpotShare] .env load skipped: $e');
    }
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[SpotShare] Firestore persistence setup skipped: $e');
    }
  }

  runApp(
    ProviderScope(
      child: DevicePreview(
        enabled: !kReleaseMode && kIsWeb,
        builder: (_) => const SpotShareApp(),
      ),
    ),
  );
}

class SpotShareApp extends ConsumerWidget {
  const SpotShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SpotShare',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SpotShareScrollBehavior(),
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      themeMode: ThemeMode.system,
      theme: CompactUiTheme.light(),
      darkTheme: CompactUiTheme.dark(),
      routerConfig: router,
    );
  }
}