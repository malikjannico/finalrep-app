import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'repositories/competition_repository.dart';
import 'providers/competition_provider.dart';
import 'views/search_feed_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Client
  await Supabase.initialize(
    url: 'https://vnseudpajhkicezdcsuj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZuc2V1ZHBhamhraWNlemRjc3VqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyOTQ4NjIsImV4cCI6MjA5NDg3MDg2Mn0.qaIyqbVOH_qXvUfz7iCvUvBsywyviFVaIYjt6MG-lsE',
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
