import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Initializing Supabase...');
  await Supabase.initialize(
    url: 'https://vnseudpajhkicezdcsuj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZuc2V1ZHBhamhraWNlemRjc3VqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyOTQ4NjIsImV4cCI6MjA5NDg3MDg2Mn0.qaIyqbVOH_qXvUfz7iCvUvBsywyviFVaIYjt6MG-lsE',
  );
  final client = Supabase.instance.client;

  try {
    print('Querying profiles...');
    final profiles = await client.from('profiles').select().limit(5);
    print('Profiles: $profiles');

    print('Querying meet_results...');
    final results = await client.from('meet_results').select().limit(5);
    print('Meet Results: $results');

    print('Querying meet_registrations...');
    final regs = await client.from('meet_registrations').select().limit(5);
    print('Meet Registrations: $regs');

  } catch (e) {
    print('Error: $e');
  }
}
