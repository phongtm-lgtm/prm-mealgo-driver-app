import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/shared/widgets/server_error_view.dart';

void main() {
  testWidgets('Server error provides a retry action', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ServerErrorView(loading: false, onRetry: () => retries++),
      ),
    );
    expect(find.text('Không thể kết nối máy chủ'), findsOneWidget);
    await tester.tap(find.text('Tải lại'));
    expect(retries, 1);
  });

  testWidgets('Retry is disabled while loading', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ServerErrorView(loading: true, onRetry: () => retries++),
      ),
    );
    expect(find.text('Đang tải lại...'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(retries, 0);
  });
}
