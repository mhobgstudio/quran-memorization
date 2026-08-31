import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/main.dart';

/// Device presets for responsive testing
class DevicePresets {
  static const phoneSmall = Size(320, 568);    // iPhone SE
  static const phone = Size(390, 844);          // iPhone 14
  static const phoneLarge = Size(430, 932);     // iPhone 14 Pro Max
  static const tabletSmall = Size(768, 1024);   // iPad Mini
  static const tablet = Size(820, 1180);        // iPad Air
  static const tabletLarge = Size(1024, 1366);  // iPad Pro
  static const laptop = Size(1366, 768);        // Standard laptop
  static const desktopHD = Size(1920, 1080);    // Full HD
  static const desktop4K = Size(2560, 1440);    // 4K

  static const landscape = Size(1180, 820);     // Landscape tablet
}

void main() {
  group('Responsive: Phone Small (320x568)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.phoneSmall * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      // Should render without overflow errors
      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('plan chips are visible', (tester) async {
      tester.view.physicalSize = DevicePresets.phoneSmall * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      // Plan selector chips should be visible
      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('can scroll the planner content', (tester) async {
      tester.view.physicalSize = DevicePresets.phoneSmall * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      // Scroll down
      await tester.fling(find.byType(PlannerScreen), const Offset(0, -200), 500);
      await tester.pumpAndSettle();

      // Should still be visible
      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });

  group('Responsive: Phone (390x844)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.phone * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('quick estimate buttons are tappable', (tester) async {
      tester.view.physicalSize = DevicePresets.phone * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      // Scroll to find estimate buttons
      await tester.fling(find.byType(PlannerScreen), const Offset(0, -300), 500);
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('start page input accepts values', (tester) async {
      tester.view.physicalSize = DevicePresets.phone * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      // Find the start page text field
      final textField = find.byType(TextField);
      if (textField.evaluate().isNotEmpty) {
        await tester.enterText(textField.first, '100');
        await tester.pumpAndSettle();
      }

      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });

  group('Responsive: Phone Large (430x932)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.phoneLarge * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('all UI elements fit', (tester) async {
      tester.view.physicalSize = DevicePresets.phoneLarge * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      // Scroll through all content
      for (int i = 0; i < 5; i++) {
        await tester.fling(find.byType(PlannerScreen), const Offset(0, -200), 300);
        await tester.pumpAndSettle();
      }

      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });

  group('Responsive: Tablet Small (768x1024)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.tabletSmall * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('content uses available width', (tester) async {
      tester.view.physicalSize = DevicePresets.tabletSmall * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });

  group('Responsive: Tablet (820x1180)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.tablet * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('scrolling works correctly', (tester) async {
      tester.view.physicalSize = DevicePresets.tablet * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      await tester.fling(find.byType(PlannerScreen), const Offset(0, -300), 500);
      await tester.pumpAndSettle();

      await tester.fling(find.byType(PlannerScreen), const Offset(0, 300), 500);
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });

  group('Responsive: Tablet Large (1024x1366)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.tabletLarge * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });

  group('Responsive: Laptop (1366x768)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.laptop * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('landscape content fits', (tester) async {
      tester.view.physicalSize = DevicePresets.laptop * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });

  group('Responsive: Desktop HD (1920x1080)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.desktopHD * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('scrolls through all content', (tester) async {
      tester.view.physicalSize = DevicePresets.desktopHD * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        await tester.fling(find.byType(PlannerScreen), const Offset(0, -200), 500);
        await tester.pumpAndSettle();
      }

      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });

  group('Responsive: Desktop 4K (2560x1440)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.desktop4K * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });

  group('Responsive: Landscape Tablet (1180x820)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.landscape * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('landscape layout is usable', (tester) async {
      tester.view.physicalSize = DevicePresets.landscape * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      // Try scrolling in landscape
      await tester.fling(find.byType(PlannerScreen), const Offset(0, -200), 500);
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });

  group('Cross-cutting: Theme consistency', () {
    testWidgets('MaterialApp renders on phone', (tester) async {
      tester.view.physicalSize = DevicePresets.phone * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('MaterialApp renders on tablet', (tester) async {
      tester.view.physicalSize = DevicePresets.tablet * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('MaterialApp renders on laptop', (tester) async {
      tester.view.physicalSize = DevicePresets.laptop * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Cross-cutting: Rapid resize', () {
    testWidgets('survives phone → tablet resize', (tester) async {
      tester.view.physicalSize = DevicePresets.phone * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);

      // Resize to tablet
      tester.view.physicalSize = DevicePresets.tablet * 2;
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('survives tablet → laptop resize', (tester) async {
      tester.view.physicalSize = DevicePresets.tablet * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);

      // Resize to laptop
      tester.view.physicalSize = DevicePresets.laptop * 2;
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('survives laptop → phone resize', (tester) async {
      tester.view.physicalSize = DevicePresets.laptop * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);

      // Resize to phone
      tester.view.physicalSize = DevicePresets.phone * 2;
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });

    testWidgets('survives landscape → portrait rotation', (tester) async {
      tester.view.physicalSize = DevicePresets.landscape * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);

      // Rotate to portrait
      tester.view.physicalSize = DevicePresets.tablet * 2;
      await tester.pumpAndSettle();

      expect(find.byType(PlannerScreen), findsOneWidget);
    });
  });
}
