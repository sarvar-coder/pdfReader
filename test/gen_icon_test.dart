// One-off generator for the app icon / splash logo. Run with:
//   flutter test test/gen_icon_test.dart
// It paints an ember on the warm paper background and writes PNGs into
// assets/icon/. Not a real test — just a convenient way to rasterize with the
// Flutter engine (no ImageMagick needed). After running it:
//   dart run flutter_launcher_icons        # app icons
//   dart run flutter_native_splash:create  # splash screen
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _paintIcon(String path, {required bool background}) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = const Offset(size / 2, size / 2);
  final radius = size * 0.32;

  if (background) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = const Color(0xFFF1E9DB),
    );
  }

  // Soft halo.
  canvas.drawCircle(
    center,
    radius * 1.35,
    Paint()
      ..color = const Color(0xFFFF8A3D).withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
  );

  // Ember body.
  final shader = ui.Gradient.radial(
    Offset(center.dx, center.dy + radius * 0.2),
    radius,
    const [
      Color(0xFFFFD28A),
      Color(0xFFF59331),
      Color(0xFFD8551D),
      Color(0xFF9C3B14),
    ],
    const [0.0, 0.38, 0.7, 1.0],
  );
  canvas.drawCircle(center, radius, Paint()..shader = shader);

  final image =
      await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate app icon + splash logo', () async {
    await _paintIcon('assets/icon/ember_icon.png', background: true);
    await _paintIcon('assets/icon/ember_logo.png', background: false);
    expect(File('assets/icon/ember_icon.png').existsSync(), isTrue);
  });
}
