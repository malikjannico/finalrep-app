import 'package:flutter_test/flutter_test.dart';
import 'package:finalrep_app/models/profile.dart';

void main() {
  group('Profile Model Tests', () {
    test('Parse Profile from JSON with all fields', () {
      final json = {
        'id': 'user-123',
        'username': 'johndoe',
        'full_name': 'John Doe',
        'email': 'john@example.com',
        'gender': 'Male',
        'country': 'Germany',
        'profile_picture_url': 'https://example.com/avatar.png',
        'description': 'A passionate streetlifter.',
        'color_mode': 'dark',
        'created_at': '2026-05-20T20:00:00.000Z',
        'updated_at': '2026-05-20T21:00:00.000Z',
      };

      final profile = Profile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.username, 'johndoe');
      expect(profile.fullName, 'John Doe');
      expect(profile.email, 'john@example.com');
      expect(profile.gender, 'Male');
      expect(profile.country, 'Germany');
      expect(profile.profilePictureUrl, 'https://example.com/avatar.png');
      expect(profile.description, 'A passionate streetlifter.');
      expect(profile.colorMode, 'dark');
      expect(profile.createdAt, isNotNull);
      expect(profile.updatedAt, isNotNull);
    });

    test('Parse Profile from JSON with minimal fields', () {
      final json = {
        'id': 'user-456',
        'username': 'minimalist',
        'full_name': 'Minimal User',
        'email': 'minimal@example.com',
      };

      final profile = Profile.fromJson(json);

      expect(profile.id, 'user-456');
      expect(profile.username, 'minimalist');
      expect(profile.fullName, 'Minimal User');
      expect(profile.email, 'minimal@example.com');
      expect(profile.gender, isNull);
      expect(profile.country, isNull);
      expect(profile.profilePictureUrl, isNull);
      expect(profile.description, isNull);
      expect(profile.colorMode, 'system');
      expect(profile.createdAt, isNull);
      expect(profile.updatedAt, isNull);
    });

    test('Convert Profile to JSON', () {
      final profile = Profile(
        id: 'user-789',
        username: 'janedoe',
        fullName: 'Jane Doe',
        email: 'jane@example.com',
        gender: 'Female',
        country: 'Austria',
        profilePictureUrl: 'https://example.com/jane.png',
        description: 'Streetlifting champion.',
        colorMode: 'light',
        createdAt: DateTime.parse('2026-05-20T20:00:00.000Z').toLocal(),
        updatedAt: DateTime.parse('2026-05-20T21:00:00.000Z').toLocal(),
      );

      final json = profile.toJson();

      expect(json['id'], 'user-789');
      expect(json['username'], 'janedoe');
      expect(json['full_name'], 'Jane Doe');
      expect(json['email'], 'jane@example.com');
      expect(json['gender'], 'Female');
      expect(json['country'], 'Austria');
      expect(json['profile_picture_url'], 'https://example.com/jane.png');
      expect(json['description'], 'Streetlifting champion.');
      expect(json['color_mode'], 'light');
      expect(json['created_at'], '2026-05-20T20:00:00.000Z');
      expect(json['updated_at'], '2026-05-20T21:00:00.000Z');
    });

    test('Profile copyWith', () {
      final profile = Profile(
        id: 'user-111',
        username: 'original',
        fullName: 'Original Name',
        email: 'original@example.com',
      );

      final updated = profile.copyWith(
        fullName: 'Updated Name',
        colorMode: 'dark',
      );

      expect(updated.id, 'user-111');
      expect(updated.username, 'original');
      expect(updated.fullName, 'Updated Name');
      expect(updated.email, 'original@example.com');
      expect(updated.colorMode, 'dark');
      expect(updated.gender, isNull);
    });
  });
}
