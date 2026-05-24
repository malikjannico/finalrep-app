import 'dart:convert';

class UuidHelper {
  /// Converts any string (e.g. Firebase Auth UID) deterministically into a valid UUID v4 string.
  static String getDeterministicUuid(String input) {
    // If the input is already a valid UUID, return it directly
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidRegex.hasMatch(input)) {
      return input.toLowerCase();
    }

    // A simple, pure-Dart deterministic hashing function (FNV-1a 32-bit based)
    // to generate 128 bits of data.
    int fnv1a(String str, int seed) {
      int hash = seed;
      final bytes = utf8.encode(str);
      for (final byte in bytes) {
        hash ^= byte;
        hash = (hash * 16777619) & 0xFFFFFFFF;
      }
      return hash;
    }

    final h1 = fnv1a(input, 2166136261);
    final h2 = fnv1a(input + "_salt1", 2166136261);
    final h3 = fnv1a(input + "_salt2", 2166136261);
    final h4 = fnv1a(input + "_salt3", 2166136261);

    String hex(int val) => val.toRadixString(16).padLeft(8, '0');

    final hexString = hex(h1) + hex(h2) + hex(h3) + hex(h4);

    // Construct a standard UUID v4 format: 8-4-4-4-12 hex digits
    // UUID v4 format requires:
    // - M (position 12) must be '4'
    // - N (position 16) must be '8', '9', 'a', or 'b'
    final buffer = StringBuffer();
    buffer.write(hexString.substring(0, 8));
    buffer.write('-');
    buffer.write(hexString.substring(8, 12));
    buffer.write('-');
    buffer.write('4'); // M = 4
    buffer.write(hexString.substring(13, 16));
    buffer.write('-');
    buffer.write('8'); // N = 8
    buffer.write(hexString.substring(17, 20));
    buffer.write('-');
    buffer.write(hexString.substring(20, 32));

    return buffer.toString();
  }
}
