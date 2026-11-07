import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zavero/models/models.dart';
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

  testWidgets('HallPillTab renders icon, name and handles tap', (WidgetTester tester) async {
    bool tapped = false;
    final testHall = Hall(id: 1, name: 'Zal', icon: Icons.table_restaurant_rounded);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HallPillTab(
            hall: testHall,
            isSelected: true,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Zal'), findsOneWidget);
    expect(find.byIcon(Icons.table_restaurant_rounded), findsOneWidget);

    await tester.tap(find.text('Zal'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('Hall tabs horizontal scroll and dynamic list test', (WidgetTester tester) async {
    final halls = [
      Hall(id: 1, name: 'Zal', icon: Icons.table_restaurant_rounded),
      Hall(id: 2, name: 'Padval', icon: Icons.stairs_rounded),
      Hall(id: 3, name: 'Dala', icon: Icons.park_rounded),
      Hall(id: 4, name: 'SABOY', icon: Icons.shopping_bag_outlined),
      Hall(id: 5, name: 'VIP Zal', icon: Icons.star_rounded),
    ];
    int selectedId = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (int i = 0; i < halls.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      HallPillTab(
                        hall: halls[i],
                        isSelected: selectedId == halls[i].id,
                        onTap: () {
                          setState(() {
                            selectedId = halls[i].id;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    for (final h in halls) {
      expect(find.text(h.name), findsOneWidget);
    }

    // Tap 'VIP Zal'
    await tester.tap(find.text('VIP Zal'));
    await tester.pumpAndSettle();
    expect(selectedId, equals(5));
  });
}
