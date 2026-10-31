import 'package:flutter/material.dart';

class EditorTextBox {
  EditorTextBox({
    required this.rect,
    this.text = '',
    this.fontFamily = 'Dekko',
    this.fontSize = 24,
  });

  Rect rect;
  String text;
  String fontFamily;
  double fontSize;

  factory EditorTextBox.fromJson(Map<String, dynamic> json) => EditorTextBox(
    rect: Rect.fromLTWH(
      (json['x'] as num?)?.toDouble() ?? 0,
      (json['y'] as num?)?.toDouble() ?? 0,
      (json['w'] as num?)?.toDouble() ?? 240,
      (json['h'] as num?)?.toDouble() ?? 80,
    ),
    text: json['t'] as String? ?? '',
    fontFamily: json['f'] as String? ?? 'Dekko',
    fontSize: (json['s'] as num?)?.toDouble() ?? 24,
  );

  Map<String, dynamic> toJson() => {
    'x': rect.left,
    'y': rect.top,
    'w': rect.width,
    'h': rect.height,
    't': text,
    'f': fontFamily,
    's': fontSize,
  };
}
