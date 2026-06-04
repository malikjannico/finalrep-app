import 'dart:io';
import 'package:postgres/postgres.dart';

class DbConnection {
  static Connection? _connection;

  static set connection(Connection conn) => _connection = conn;

  static Future<Connection> get connection async {
    if (_connection != null) {
      return _connection!;
    }

    final host = Platform.environment['DB_HOST'] ?? 'localhost';
    final port = int.tryParse(Platform.environment['DB_PORT'] ?? '5432') ?? 5432;
    final database = Platform.environment['DB_NAME'] ?? 'finalrep_db';
    final username = Platform.environment['DB_USER'] ?? 'app_user';
    final password = Platform.environment['DB_PASS'] ?? 'app_dev_db_password';
    final socketPath = Platform.environment['DB_SOCKET_PATH']; // e.g. /cloudsql/project:region:instance

    Endpoint endpoint;
    if (socketPath != null && socketPath.isNotEmpty) {
      // Connect via unix socket in Cloud Run
      endpoint = Endpoint(
        host: socketPath,
        port: 0,
        database: database,
        username: username,
        password: password,
      );
    } else {
      // Connect via TCP locally
      endpoint = Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      );
    }

    _connection = await Connection.open(
      endpoint,
      settings: ConnectionSettings(
        sslMode: socketPath != null ? SslMode.disable : SslMode.disable, // Unix sockets don't use SSL
      ),
    );

    // Run migration: Rename 'gender' to 'sex' in profiles table if it still exists
    try {
      final checkResult = await _connection!.execute(
        Sql.named('''
          SELECT column_name 
          FROM information_schema.columns 
          WHERE table_schema = 'public' 
            AND table_name = 'profiles' 
            AND column_name = 'gender'
        '''),
      );
      if (checkResult.isNotEmpty) {
        await _connection!.execute(
          Sql.named('ALTER TABLE public.profiles RENAME COLUMN gender TO sex'),
        );
        print('DB MIGRATION: Renamed public.profiles.gender to sex.');
      }
    } catch (e) {
      print('DB MIGRATION WARNING: Failed to rename profiles.gender to sex: $e');
    }

    // Run migration: Add new columns if they do not exist
    final migrationColumns = [
      {'table': 'competitions', 'column': 'ranking_type', 'type': 'TEXT NOT NULL DEFAULT \'open\''},
      {'table': 'associations', 'column': 'rulebooks_sharing', 'type': 'JSONB NOT NULL DEFAULT \'{}\'::jsonb'},
      {'table': 'associations', 'column': 'applied_shared_resources', 'type': 'JSONB NOT NULL DEFAULT \'{"rulebooks": {}, "competition_groups": [], "athlete_groups": []}\'::jsonb'},
      {'table': 'competition_groups', 'column': 'sharing_config', 'type': 'JSONB NOT NULL DEFAULT \'{"mode": "private", "targets": []}\'::jsonb'},
      {'table': 'athlete_groups', 'column': 'sharing_config', 'type': 'JSONB NOT NULL DEFAULT \'{"mode": "private", "targets": []}\'::jsonb'},
      {'table': 'competitions', 'column': 'latitude', 'type': 'DOUBLE PRECISION'},
      {'table': 'competitions', 'column': 'longitude', 'type': 'DOUBLE PRECISION'},
    ];

    for (final col in migrationColumns) {
      try {
        final check = await _connection!.execute(
          Sql.named('''
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
              AND table_name = '${col['table']}' 
              AND column_name = '${col['column']}'
          '''),
        );
        if (check.isEmpty) {
          await _connection!.execute(
            Sql.named('ALTER TABLE public.${col['table']} ADD COLUMN ${col['column']} ${col['type']}'),
          );
          print('DB MIGRATION: Added column public.${col['table']}.${col['column']}.');
        }
      } catch (e) {
        print('DB MIGRATION WARNING: Failed to add column public.${col['table']}.${col['column']}: $e');
      }
    }

    try {
      final checkResult = await _connection!.execute(
        Sql.named('''
          SELECT column_name 
          FROM information_schema.columns 
          WHERE table_schema = 'public' 
            AND table_name = 'athlete_groups' 
            AND column_name = 'competition_group_id'
        '''),
      );
      if (checkResult.isNotEmpty) {
        await _connection!.execute(
          Sql.named('ALTER TABLE public.athlete_groups DROP COLUMN competition_group_id'),
        );
        print('DB MIGRATION: Dropped competition_group_id column from public.athlete_groups.');
      }
    } catch (e) {
      print('DB MIGRATION WARNING: Failed to drop competition_group_id column: $e');
    }

    return _connection!;
  }
}
