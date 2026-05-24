import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finalrep_app/repositories/profile_repository.dart';

class SimpleMockSupabaseClient implements SupabaseClient {
  final List<Map<String, dynamic>> rankingsData;
  final List<Map<String, dynamic>> competitionsData;

  SimpleMockSupabaseClient({
    required this.rankingsData,
    required this.competitionsData,
  });

  @override
  SupabaseQueryBuilder from(String table) {
    return SimpleMockQueryBuilder(table, this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SimpleMockQueryBuilder implements SupabaseQueryBuilder {
  final String table;
  final SimpleMockSupabaseClient client;

  SimpleMockQueryBuilder(this.table, this.client);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #select) {
      return SimpleMockFilterBuilder<List<Map<String, dynamic>>>(table, client);
    }
    return super.noSuchMethod(invocation);
  }
}

// ignore: must_be_immutable
class SimpleMockFilterBuilder<T>
    implements PostgrestFilterBuilder<T>, Future<T> {
  final String table;
  final SimpleMockSupabaseClient client;
  final Map<String, dynamic> eqFilters = {};
  List<String>? inFilterTitles;

  SimpleMockFilterBuilder(this.table, this.client);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    print('SimpleMockFilterBuilder noSuchMethod called: $name');
    if (name == #eq) {
      final col = invocation.positionalArguments[0] as String;
      final val = invocation.positionalArguments[1];
      eqFilters[col] = val;
      return this;
    }
    if (name == #inFilter) {
      final col = invocation.positionalArguments[0] as String;
      final val = invocation.positionalArguments[1] as List;
      print('inFilter called with col: $col, values: $val');
      if (col == 'title') {
        inFilterTitles = val.cast<String>();
      }
      return this;
    }
    return super.noSuchMethod(invocation);
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) async {
    dynamic result;
    if (table == 'highest_rankings') {
      result = client.rankingsData;
    } else if (table == 'competitions') {
      if (inFilterTitles != null) {
        result = client.competitionsData
            .where((c) => inFilterTitles!.contains(c['title']))
            .toList();
      } else {
        result = client.competitionsData;
      }
    } else {
      result = [];
    }
    print('SimpleMockFilterBuilder then returns for table $table: $result');
    return onValue(result as T);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return Future<T>.value().catchError(onError, test: test);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return Future<T>.value().timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Stream<T> asStream() {
    return Stream<T>.empty();
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return Future<T>.value().whenComplete(action);
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

        final client = SimpleMockSupabaseClient(
          rankingsData: rankings,
          competitionsData: competitions,
        );

        final repo = ProfileRepository(client);
        final results = await repo.getUserHighestRankings('user-1');

        print('RESULTS: $results');

        // The upcoming ranking (Hamburg Streetlifting Meet) should be filtered out.
        expect(results.length, 1);
        expect(results[0]['competition'], 'Classic Pull & Dip Cup');
      },
    );
  });
}
