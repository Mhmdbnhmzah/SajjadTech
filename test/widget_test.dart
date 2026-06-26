// This is a basic Flutter widget test for SajjadTech.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:sajjadtech/main.dart';

void main() {
  testWidgets('App starts and displays LoginView', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the login view is displayed by checking for the login button text.
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}

