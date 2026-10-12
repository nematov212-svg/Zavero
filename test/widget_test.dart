import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zavero/main.dart';

void main() {
  testWidgets('TableChairsIcon renders correctly with free and occupied colors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TableChairsIcon(color: Color(0xFF00C853), width: 58, height: 38),
              TableChairsIcon(color: Color(0xFFE53935), width: 58, height: 38),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(TableChairsIcon), findsNWidgets(2));
  });
}
