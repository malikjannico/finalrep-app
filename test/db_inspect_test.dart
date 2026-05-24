import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel(
      'plugins.flutter.io/shared_preferences',
    ).setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      return null;
    });
  });

  test('Inspect profiles table schema', () async {
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
          .eq('username', 'nonexistent_test_user_123')
          .maybeSingle();
      print('DB RESPONSE FOR SELECT: $response');
    } catch (e) {
      print('DB INSPECT ERROR: $e');
      if (e is PostgrestException) {
        print(
          'PostgrestException details: ${e.message}, ${e.code}, ${e.details}, ${e.hint}',
        );
      }
    }
  });
}
