import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'views/search_feed_page.dart';
import 'utils/url_helper.dart';
import 'utils/mock_safety.dart';

void main() async {
  UrlHelper.initialize();
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

  // Create a placeholder/dummy SupabaseClient for repository construction in test/dev modes
  final supabase = SupabaseClient(
    'https://placeholder.supabase.co',
    'placeholder-anon-key',
  );
  final competitionRepository = CompetitionRepository(supabase);
  final profileRepository = ProfileRepository(supabase);
  final adminRepository = AdminRepository(supabase);
  final associationRepository = AssociationRepository(supabase);
  final notificationRepository = NotificationRepository(supabase);

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
            supabase,
            profileRepository,
            adminRepository: adminRepository,
            notificationRepository: notificationRepository,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true; // Defaulting to premium dark mode for guests

  void _toggleTheme(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated &&
        authProvider.currentUserProfile != null) {
      final profile = authProvider.currentUserProfile!;
      final currentMode = profile.colorMode;
      String newMode;
      if (currentMode == 'system') {
        // Toggle based on platform brightness
        final isSystemDark =
            MediaQuery.of(context).platformBrightness == Brightness.dark;
        newMode = isSystemDark ? 'light' : 'dark';
      } else {
        newMode = currentMode == 'dark' ? 'light' : 'dark';
      }
      authProvider.updateProfile(
        fullName: profile.fullName,
        email: profile.email,
        gender: profile.gender,
        country: profile.country,
        description: profile.description,
        colorMode: newMode,
      );
    } else {
      setState(() {
        _isDarkMode = !_isDarkMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
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
          themeMode = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
          isDarkTheme = _isDarkMode;
        }

        return MaterialApp(
          title: 'FinalRep App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          themeAnimationDuration: Duration.zero,
          navigatorObservers: [
            WebUrlObserver(
              Provider.of<CompetitionProvider>(context, listen: false),
            ),
          ],
          initialRoute: '/',
          home: Builder(
            builder: (context) => SearchFeedPage(
              onToggleTheme: () => _toggleTheme(context),
              isDarkMode: isDarkTheme,
            ),
          ),
        );
      },
    );
  }
}
