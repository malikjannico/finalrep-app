import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finalrep_app/models/competition.dart';
import 'package:finalrep_app/repositories/competition_repository.dart';
import 'package:finalrep_app/providers/competition_provider.dart';
import 'package:finalrep_app/views/search_feed_page.dart';

// Mock repository for UI testing
class FakeCompetitionRepository implements CompetitionRepository {
  final List<Competition> _fakeCompetitions = [
    Competition(
      id: '1',
      title: 'Hamburg Streetlifting Meet',
      location: 'Hamburg, Germany',
      sportSubtype: 'Modern',
      compGroupName: 'FinalRep Qualifier',
      startDate: DateTime.now().add(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Competition(
      id: '2',
      title: 'Classic Pull & Dip Cup',
      location: 'Berlin, Germany',
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
  }) async {
    return _fakeCompetitions.where((comp) {
      if (query != null && query.isNotEmpty) {
        if (!comp.title.toLowerCase().contains(query.toLowerCase())) return false;
      }
      if (sportSubtype != null && sportSubtype != 'All' && comp.sportSubtype != sportSubtype) {
        return false;
      }
      if (compGroupName != null && compGroupName != 'All') {
        if (compGroupName == 'Individual') {
          if (comp.compGroupName != null) return false;
        } else if (comp.compGroupName != compGroupName) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}

void main() {
  testWidgets('SearchFeedPage Renders and Filters Competitions', (WidgetTester tester) async {
    final repo = FakeCompetitionRepository();
    final provider = CompetitionProvider(repo);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CompetitionProvider>.value(value: provider),
        ],
        child: MaterialApp(
          home: SearchFeedPage(
            onToggleTheme: () {},
            isDarkMode: true,
          ),
        ),
      ),
    );

    // Initial load frame
    await tester.pump();
    await tester.pump(Duration.zero); // Wait for provider fetch complete

    // Verify title and header logo elements exist
    expect(find.text('Competitions'), findsAtLeast(1));
    expect(find.byType(TextField), findsOneWidget);

    // Verify both mock competitions exist on feed
    expect(find.text('Hamburg Streetlifting Meet'), findsOneWidget);
    expect(find.text('Classic Pull & Dip Cup'), findsOneWidget);

    // Verify modern/classic badge details
    expect(find.text('MODERN'), findsOneWidget);
    expect(find.text('CLASSIC'), findsOneWidget);

    // Filter by Modern subtype
    // Tap on the Format dropdown chip
    final formatChip = find.text('Format');
    expect(formatChip, findsOneWidget);
    await tester.tap(formatChip);
    await tester.pumpAndSettle(); // Settle popup menu open animation

    // Tap on 'Modern' in the menu
    final modernMenuItem = find.text('Modern');
    expect(modernMenuItem, findsAtLeast(1));
    await tester.tap(modernMenuItem.last);
    await tester.pumpAndSettle(); // Settle popup menu close animation

    // Verify Classic competition is now filtered out
    expect(find.text('Hamburg Streetlifting Meet'), findsOneWidget);
    expect(find.text('Classic Pull & Dip Cup'), findsNothing);
  });
}
