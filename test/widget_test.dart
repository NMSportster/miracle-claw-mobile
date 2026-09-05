// Basic widget test — ensures the app boots into the splash screen without crashing.
//
// Run with: flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miracle_claw_mobile/app.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MiracleClawApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
