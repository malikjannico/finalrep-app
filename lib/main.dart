import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'theme.dart';
import 'repositories/competition_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/admin_repository.dart';
import 'repositories/association_repository.dart';
import 'repositories/notification_repository.dart';
import 'providers/competition_provider.dart';
import 'providers/auth_provider.dart';
import 'views/home_navigation_shell.dart';
import 'utils/mock_safety.dart';
import 'router.dart';

void main() async {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Intercept pointer data packets to map trackpad device kind to mouse,
  // preventing the gestures library assertion in Flutter Web.
  final originalOnPointerDataPacket =
      ui.PlatformDispatcher.instance.onPointerDataPacket;
  if (originalOnPointerDataPacket != null) {
    ui.PlatformDispatcher.instance.onPointerDataPacket =
        (ui.PointerDataPacket packet) {
          final modifiedData = packet.data.map((ui.PointerData data) {
            if (data.kind == ui.PointerDeviceKind.trackpad) {
              return ui.PointerData(
                viewId: data.viewId,
                embedderId: data.embedderId,
                timeStamp: data.timeStamp,
                change: data.change,
                kind: ui.PointerDeviceKind.mouse,
                signalKind: data.signalKind,
                device: data.device,
                pointerIdentifier: data.pointerIdentifier,
                physicalX: data.physicalX,
                physicalY: data.physicalY,
                physicalDeltaX: data.physicalDeltaX,
                physicalDeltaY: data.physicalDeltaY,
                buttons: data.buttons,
                obscured: data.obscured,
                synthesized: data.synthesized,
                pressure: data.pressure,
                pressureMin: data.pressureMin,
                pressureMax: data.pressureMax,
                distance: data.distance,
                distanceMax: data.distanceMax,
                size: data.size,
                radiusMajor: data.radiusMajor,
                radiusMinor: data.radiusMinor,
                radiusMin: data.radiusMin,
                radiusMax: data.radiusMax,
                orientation: data.orientation,
                tilt: data.tilt,
                platformData: data.platformData,
                scrollDeltaX: data.scrollDeltaX,
                scrollDeltaY: data.scrollDeltaY,
                panX: data.panX,
                panY: data.panY,
                panDeltaX: data.panDeltaX,
                panDeltaY: data.panDeltaY,
                scale: data.scale,
                rotation: data.rotation,
              );
            }
            return data;
          }).toList();

          originalOnPointerDataPacket(ui.PointerDataPacket(data: modifiedData));
        };
  }

  // Validate environment variables and keys
  MockSafety.validateStartupConfiguration();

  // Initialize Firebase if credentials are provided
  if (MockSafety.hasFirebaseKeys) {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: MockSafety.firebaseApiKey,
          authDomain: MockSafety.firebaseAuthDomain,
          projectId: MockSafety.firebaseProjectId,
          storageBucket: MockSafety.firebaseStorageBucket,
          messagingSenderId: MockSafety.firebaseMessagingSenderId,
          appId: MockSafety.firebaseAppId,
        ),
      );
    } catch (e) {
      if (MockSafety.env == 'staging' || MockSafety.env == 'prod') {
        throw StateError(
          'CRITICAL: Firebase failed to initialize in "${MockSafety.env}": $e',
        );
      }
      debugPrint('Firebase failed to initialize (using mock fallback in dev): $e');
    }
  }

  final competitionRepository = CompetitionRepository();
  final profileRepository = ProfileRepository();
  final adminRepository = AdminRepository();
  final associationRepository = AssociationRepository();
  final notificationRepository = NotificationRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CompetitionProvider(
            competitionRepository,
            profileRepository,
            associationRepository: associationRepository,
            notificationRepository: notificationRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            profileRepository,
            adminRepository: adminRepository,
            notificationRepository: notificationRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated &&
        authProvider.currentUserProfile != null) {
      final profile = authProvider.currentUserProfile!;
      final currentMode = profile.colorMode;
      String newMode;
      if (currentMode == 'system') {
        final isSystemDark =
            MediaQuery.of(context).platformBrightness == Brightness.dark;
        newMode = isSystemDark ? 'light' : 'dark';
      } else {
        newMode = currentMode == 'dark' ? 'light' : 'dark';
      }
      authProvider.updateProfile(
        fullName: profile.fullName,
        email: profile.email,
        sex: profile.sex,
        country: profile.country,
        description: profile.description,
        colorMode: newMode,
      );
    } else {
      _isDarkMode = !_isDarkMode;
      notifyListeners();
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void _toggleTheme(BuildContext context) {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, authProvider, themeProvider, _) {
        final profile = authProvider.currentUserProfile;
        ThemeMode themeMode;
        bool isDarkTheme;

        if (authProvider.isAuthenticated && profile != null) {
          final mode = profile.colorMode;
          if (mode == 'light') {
            themeMode = ThemeMode.light;
            isDarkTheme = false;
          } else if (mode == 'dark') {
            themeMode = ThemeMode.dark;
            isDarkTheme = true;
          } else {
            themeMode = ThemeMode.system;
            isDarkTheme =
                MediaQuery.of(context).platformBrightness == Brightness.dark;
          }
        } else {
          themeMode = themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light;
          isDarkTheme = themeProvider.isDarkMode;
        }

        return MaterialApp.router(
          title: 'FinalRep App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          themeAnimationDuration: Duration.zero,
          routerConfig: goRouter,
        );
      },
    );
  }
}
