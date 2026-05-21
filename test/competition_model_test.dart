import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/models/competition.dart';

void main() {
  group('Competition Model Tests', () {
    test('Parse Modern Streetlifting Competition from JSON', () {
      final json = {
        'id': 'a3b838c6-3023-4552-bf6d-9be24ad90209',
        'title': 'German Streetlifting Championship 2026',
        'description': 'The biggest Modern streetlifting event.',
        'start_date': '2026-06-15T09:00:00Z',
        'end_date': '2026-06-15T18:00:00Z',
        'location': 'Hamburg, Germany',
        'sport_type': 'Streetlifting',
        'sport_subtype': 'Modern',
        'comp_group_name': 'FinalRep Qualifier',
        'status': 'upcoming',
        'area': 'Europe',
        'country': 'Germany',
        'city': 'Hamburg',
        'title_image_url': 'assets/images/comp_hamburg.png',
        'created_at': '2026-05-20T20:00:00Z',
        'updated_at': '2026-05-20T20:00:00Z',
      };

      final comp = Competition.fromJson(json);

      expect(comp.id, 'a3b838c6-3023-4552-bf6d-9be24ad90209');
      expect(comp.title, 'German Streetlifting Championship 2026');
      expect(comp.sportSubtype, 'Modern');
      expect(comp.isModern, true);
      expect(comp.isClassic, false);
      expect(comp.isPartOfGroup, true);
      expect(comp.compGroupName, 'FinalRep Qualifier');
      expect(comp.area, 'Europe');
      expect(comp.country, 'Germany');
      expect(comp.city, 'Hamburg');
      expect(comp.titleImageUrl, 'assets/images/comp_hamburg.png');
      expect(comp.disciplines, ['Muscle Up', 'Pull Up', 'Dip', 'Squat']);
    });

    test('Parse Classic Streetlifting Competition from JSON', () {
      final json = {
        'id': 'b1c3c9d7-8cf2-4412-a7f4-dcd7b7890f55',
        'title': 'Underground Pull & Dip Meet',
        'description': null,
        'start_date': '2026-07-10T10:00:00Z',
        'end_date': '2026-07-10T17:00:00Z',
        'location': 'Berlin, Germany',
        'sport_type': 'Streetlifting',
        'sport_subtype': 'Classic',
        'comp_group_name': null,
        'status': 'upcoming',
        'area': 'Europe',
        'country': 'Germany',
        'city': 'Berlin',
        'title_image_url': null,
        'created_at': '2026-05-20T20:00:00Z',
        'updated_at': '2026-05-20T20:00:00Z',
      };

      final comp = Competition.fromJson(json);

      expect(comp.isModern, false);
      expect(comp.isClassic, true);
      expect(comp.isPartOfGroup, false);
      expect(comp.area, 'Europe');
      expect(comp.country, 'Germany');
      expect(comp.city, 'Berlin');
      expect(comp.titleImageUrl, isNull);
      expect(comp.disciplines, ['Pull Up', 'Dip']);
    });
  });
}
