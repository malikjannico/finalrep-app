import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:finalrep_app/repositories/profile_repository.dart';
import 'package:finalrep_app/utils/api_client.dart';

class SimpleMockApiClient extends ApiClient {
  final List<Map<String, dynamic>> rankingsData;
  final List<Map<String, dynamic>> competitionsData;

  SimpleMockApiClient({
    required this.rankingsData,
    required this.competitionsData,
  });

  @override
  Future<http.Response> get(String path, {Map<String, String>? queryParameters}) async {
    if (path == '/profiles' && queryParameters?['type'] == 'rankings') {
      return http.Response(jsonEncode(rankingsData), 200);
    }
    if (path == '/competitions' && queryParameters?['status'] == 'completed') {
      final completed = competitionsData.where((c) => c['status'] == 'completed').toList();
      return http.Response(jsonEncode(completed), 200);
    }
    return http.Response('Not found', 404);
  }
}

void main() {
  group('ProfileRepository Tests', () {
    test(
      'getUserHighestRankings filters out upcoming competition rankings',
      () async {
        final rankings = [
          {
            'profile_id': 'user-1',
            'discipline': 'Overall Modern (-80kg)',
            'rank': '2nd Place',
            'competition': 'Hamburg Streetlifting Meet',
          },
          {
            'profile_id': 'user-1',
            'discipline': 'Overall Modern (-80kg)',
            'rank': '1st Place',
            'competition': 'Classic Pull & Dip Cup',
          },
        ];

        final competitions = [
          {'title': 'Hamburg Streetlifting Meet', 'status': 'upcoming'},
          {'title': 'Classic Pull & Dip Cup', 'status': 'completed'},
        ];

        final api = SimpleMockApiClient(
          rankingsData: rankings,
          competitionsData: competitions,
        );

        final repo = ProfileRepository(api: api);
        final results = await repo.getUserHighestRankings('user-1');

        print('RESULTS: $results');

        // The upcoming ranking (Hamburg Streetlifting Meet) should be filtered out.
        expect(results.length, 1);
        expect(results[0]['competition'], 'Classic Pull & Dip Cup');
      },
    );
  });
}
