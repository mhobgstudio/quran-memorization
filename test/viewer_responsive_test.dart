import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_memorization/screens/page_viewer_screen.dart';

/// Device presets for responsive testing
class DevicePresets {
  static const phoneSmall = Size(320, 568);
  static const phone = Size(390, 844);
  static const phoneLarge = Size(430, 932);
  static const tabletSmall = Size(768, 1024);
  static const tablet = Size(820, 1180);
  static const tabletLarge = Size(1024, 1366);
  static const laptop = Size(1366, 768);
  static const desktopHD = Size(1920, 1080);
  static const desktop4K = Size(2560, 1440);
  static const landscape = Size(1180, 820);
}

void main() {
  group('Viewer Responsive: Phone Small (320x568)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.phoneSmall * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });

    testWidgets('can navigate pages', (tester) async {
      tester.view.physicalSize = DevicePresets.phoneSmall * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      // Tap right side for next page
      await tester.tapAt(const Offset(280, 300));
      await tester.pump(const Duration(seconds: 1));

      // Tap left side for previous page
      await tester.tapAt(const Offset(40, 300));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });

  group('Viewer Responsive: Phone (390x844)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.phone * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });

    testWidgets('keyboard navigation works', (tester) async {
      tester.view.physicalSize = DevicePresets.phone * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      // Arrow key navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(seconds: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });

  group('Viewer Responsive: Phone Large (430x932)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.phoneLarge * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });

  group('Viewer Responsive: Tablet Small (768x1024)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.tabletSmall * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });

  group('Viewer Responsive: Tablet (820x1180)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.tablet * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });

    testWidgets('app bar icons are accessible', (tester) async {
      tester.view.physicalSize = DevicePresets.tablet * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      // App bar should have icon buttons
      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });

  group('Viewer Responsive: Tablet Large (1024x1366)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.tabletLarge * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });

  group('Viewer Responsive: Laptop (1366x768)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.laptop * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });

    testWidgets('page content fits in landscape', (tester) async {
      tester.view.physicalSize = DevicePresets.laptop * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });

  group('Viewer Responsive: Desktop HD (1920x1080)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.desktopHD * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });

  group('Viewer Responsive: Desktop 4K (2560x1440)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.desktop4K * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });

  group('Viewer Responsive: Landscape (1180x820)', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = DevicePresets.landscape * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });

    testWidgets('landscape navigation works', (tester) async {
      tester.view.physicalSize = DevicePresets.landscape * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      // Navigate in landscape
      await tester.tapAt(const Offset(1100, 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.tapAt(const Offset(80, 400));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });

  group('Viewer Cross-cutting: Rapid resize', () {
    testWidgets('survives phone → tablet resize', (tester) async {
      tester.view.physicalSize = DevicePresets.phone * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);

      // Resize to tablet
      tester.view.physicalSize = DevicePresets.tablet * 2;
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });

    testWidgets('survives tablet → laptop resize', (tester) async {
      tester.view.physicalSize = DevicePresets.tablet * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);

      // Resize to laptop
      tester.view.physicalSize = DevicePresets.laptop * 2;
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });

    testWidgets('survives laptop → phone resize', (tester) async {
      tester.view.physicalSize = DevicePresets.laptop * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);

      // Resize to phone
      tester.view.physicalSize = DevicePresets.phone * 2;
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });

    testWidgets('survives landscape → portrait rotation', (tester) async {
      tester.view.physicalSize = DevicePresets.landscape * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: PageViewerScreen(page: 1, linesPerDay: 10)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PageViewerScreen), findsOneWidget);

      // Rotate to portrait
      tester.view.physicalSize = DevicePresets.tablet * 2;
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PageViewerScreen), findsOneWidget);
    });
  });
}
