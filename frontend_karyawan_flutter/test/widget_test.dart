// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_karyawan_flutter/main.dart';

void main() {
  testWidgets('employee app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const EmployeeApp());
    expect(find.text('Absensi Proyek'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Masuk ke akun karyawan'), findsOneWidget);
  });
}
