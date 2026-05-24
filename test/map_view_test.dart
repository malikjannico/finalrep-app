import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/models/profile.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/world_map_view.dart';

class MockProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Profile>> searchProfiles(String query) async {
    return [];
  }
}

class FakeMapCompetitionRepository implements CompetitionRepository {
  final List<Competition> _fakeCompetitions = [
    Competition(
      id: '1',
      title: 'Hamburg Meet',
      location: 'Hamburg, Germany',
      city: 'Hamburg',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      startDate: DateTime.now().add(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Competition(
      id: '2',
      title: 'Berlin Cup',
      location: 'Berlin, Germany',
      city: 'Berlin',
      sportSubtype: 'Classic',
      compGroupName: null,
      startDate: DateTime.now().add(const Duration(days: 10)),
      endDate: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Competition>> getUpcomingCompetitions({
    String? query,
    String? sportSubtype,
    String? compGroupName,
    String? status = 'upcoming',
  }) async {
    return _fakeCompetitions;
  }
}

void main() {
  testWidgets(
    'WorldMapView can rebuild, switch themes, and resize without assertion failures',
    (WidgetTester tester) async {
      // Set screen size to mobile
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeMapCompetitionRepository();
      final provider = CompetitionProvider(repo, MockProfileRepository());

      // Initial load
      await provider.fetchCompetitions();

      // Stateful theme notifier to trigger rebuilds
      final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CompetitionProvider>.value(value: provider),
          ],
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: themeMode,
            builder: (context, mode, child) {
              return MaterialApp(
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                themeMode: mode,
                home: const Scaffold(body: WorldMapView()),
              );
            },
          ),
        ),
      );

      // Initial render - use pump with a duration instead of pumpAndSettle due to infinite pulse animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify markers/elements are rendered
      expect(find.byType(WorldMapView), findsOneWidget);

      // 2. Switch theme mode to dark to trigger didUpdateWidget options update
      themeMode.value = ThemeMode.dark;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Switch theme mode back to light
      themeMode.value = ThemeMode.light;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 4. Resize the window/device to simulate orientation changes/resizing
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Resize to tablet size
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
