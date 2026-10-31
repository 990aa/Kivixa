import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kivixa/data/editor/text_box.dart';

void main() {
  test('text box preserves placement and typography in JSON', () {
    final original = EditorTextBox(
      rect: const Rect.fromLTWH(123.5, 456.25, 321, 98),
      text: 'Meeting notes',
      fontFamily: 'monospace',
      fontSize: 31.5,
    );

    final restored = EditorTextBox.fromJson(original.toJson());

    expect(restored.rect, original.rect);
    expect(restored.text, original.text);
    expect(restored.fontFamily, original.fontFamily);
    expect(restored.fontSize, original.fontSize);
  });
}
