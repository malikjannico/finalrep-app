import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test decoding 1x1 PNG', (WidgetTester tester) async {
    final Uint8List pngBytes = File(
      'assets/images/comp_berlin.png',
    ).readAsBytesSync();

    bool success = false;
    bool error = false;
    String? errMsg;
    await tester.runAsync(() async {
      final image = MemoryImage(pngBytes);
      final completer = image.resolve(ImageConfiguration.empty);
      completer.addListener(
        ImageStreamListener(
          (info, synchronousCall) {
            success = true;
            debugPrint('SUCCESS DECODING!');
          },
          onError: (exception, stackTrace) {
            error = true;
            errMsg = exception.toString();
            debugPrint('ERROR DECODING: $exception');
          },
        ),
      );

      for (int i = 0; i < 100; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
        if (success || error) break;
      }
    });
    debugPrint('Result: success=$success, error=$error, errMsg=$errMsg');
    expect(success, isTrue);
  });
}
