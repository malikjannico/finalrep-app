import 'dart:io';
import 'package:postgres/postgres.dart';

class DbConnection {
  static Connection? _connection;

  static Future<Connection> get connection async {
    if (_connection != null && !_connection!.isClosed) {
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

    return _connection!;
  }
}
