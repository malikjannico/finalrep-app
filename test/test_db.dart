import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('inspect database schema', () async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://vnseudpajhkicezdcsuj.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZuc2V1ZHBhamhraWNlemRjc3VqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyOTQ4NjIsImV4cCI6MjA5NDg3MDg2Mn0.qaIyqbVOH_qXvUfz7iCvUvBsywyviFVaIYjt6MG-lsE',
    );

    final client = Supabase.instance.client;
    try {
      final response = await client
          .from('profiles')
          .select()
          .limit(1)
          .maybeSingle();
      print('DB RESPONSE FOR PROFILE: $response');
    } catch (e) {
      print('DB ERROR: $e');
    }
  });
}
