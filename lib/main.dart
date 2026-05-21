import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'repositories/competition_repository.dart';
import 'providers/competition_provider.dart';
import 'views/search_feed_page.dart';

void main() async {
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

  // Initialize Supabase Client
  await Supabase.initialize(
    url: 'https://vnseudpajhkicezdcsuj.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZuc2V1ZHBhamhraWNlemRjc3VqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyOTQ4NjIsImV4cCI6MjA5NDg3MDg2Mn0.qaIyqbVOH_qXvUfz7iCvUvBsywyviFVaIYjt6MG-lsE',
  );

  final supabase = Supabase.instance.client;
  final competitionRepository = CompetitionRepository(supabase);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CompetitionProvider(competitionRepository),
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
  bool _isDarkMode = true; // Defaulting to premium dark mode

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinalRep App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: Duration.zero,
      home: SearchFeedPage(
        onToggleTheme: _toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}
