import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noisenet_mobile/core/theme/app_theme.dart';

void main() {
  test('app themes expose light and dark brightness correctly', () {
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
  });
}
