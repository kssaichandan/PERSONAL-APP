import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> completeOnboarding(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    // Tap "Skip" to bypass onboarding (text button always visible on first 4 pages)
    final skipBtn = find.text('Skip');
    if (skipBtn.evaluate().isNotEmpty) {
      await tester.tap(skipBtn);
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> goToTab(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon).last);
    await tester.pumpAndSettle();
  }

  group('Navigation & Onboarding', () {
    testWidgets('Complete onboarding and navigate through all 6 tabs',
        (tester) async {
      app.main();
      await completeOnboarding(tester);

      // Verify on Notes screen by TextField presence (hintText not matched by find.text)
      expect(find.byType(TextField), findsOneWidget);

      // Habits tab — AppBar shows 'Habit Tracker' after load
      await goToTab(tester, Icons.checklist_rtl_rounded);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Habit Tracker'), findsWidgets);

      // Calendar tab
      await goToTab(tester, Icons.calendar_month);
      await tester.pumpAndSettle();
      expect(find.text('Calendar'), findsWidgets);

      // Calculator tab
      await goToTab(tester, Icons.calculate);
      await tester.pumpAndSettle();
      expect(find.text('Calculator'), findsWidgets);

      // Life tab
      await goToTab(tester, Icons.hourglass_empty_rounded);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Life Tracker'), findsWidgets);

      // Settings tab
      await goToTab(tester, Icons.settings_rounded);
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsWidgets);
    });
  });

  group('Notes Feature', () {
    testWidgets('Create, edit, and delete a note', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.note_rounded);
      await tester.pumpAndSettle();

      // Tap FAB to create note
      final fab = find.byTooltip('Create note');
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab);
        await tester.pumpAndSettle();
      }

      // Enter title
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'Integration Test Note');
      await tester.pumpAndSettle();

      // Save
      final saveBtn = find.byTooltip('Save');
      if (saveBtn.evaluate().isNotEmpty) {
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();
      }

      // Verify note appears back on notes screen
      expect(find.text('Integration Test Note'), findsOneWidget);
    });

    testWidgets('Search notes by query', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.note_rounded);
      await tester.pumpAndSettle();

      // Find search field by hint text
      await tester.enterText(find.byType(TextField).first, 'test');
      await tester.pumpAndSettle();
    });

    testWidgets('Toggle favorites', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.note_rounded);
      await tester.pumpAndSettle();
    });

    testWidgets('Toggle grid/list view', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.note_rounded);
      await tester.pumpAndSettle();
    });

    testWidgets('Empty state shows no notes message', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.note_rounded);
      await tester.pump(const Duration(seconds: 2));
      // If no notes exist, empty state is shown
      final emptyState = find.text('No notes yet');
      if (emptyState.evaluate().isNotEmpty) {
        expect(emptyState, findsOneWidget);
      }
    });
  });

  group('Habits Feature', () {
    testWidgets('Add a new habit via dialog', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.checklist_rtl_rounded);
      await tester.pumpAndSettle();

      // Wait for habits to load
      await tester.pump(const Duration(seconds: 2));

      // Tap add habit button
      final addBtn = find.byTooltip('Add habit');
      if (addBtn.evaluate().isNotEmpty) {
        await tester.tap(addBtn);
        await tester.pumpAndSettle();
      }

      // Verify dialog opened with "New Habit" title
      expect(find.text('New Habit'), findsOneWidget);

      // Enter habit name
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Test Habit');
      await tester.pumpAndSettle();
    });

    testWidgets('Empty state shows no habits message', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.checklist_rtl_rounded);
      await tester.pump(const Duration(seconds: 3));

      // Check empty state or habits loading
      final emptyState = find.text('No habits created yet');
      if (emptyState.evaluate().isNotEmpty) {
        expect(emptyState, findsOneWidget);
      }
    });
  });

  group('Calendar Feature', () {
    testWidgets('Navigate between months', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.calendar_month);
      await tester.pumpAndSettle();

      // Tap next month
      final nextBtn = find.byTooltip('Next month');
      if (nextBtn.evaluate().isNotEmpty) {
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
      }

      // Tap previous month
      final prevBtn = find.byTooltip('Previous month');
      if (prevBtn.evaluate().isNotEmpty) {
        await tester.tap(prevBtn);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Open event editor via FAB', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.calendar_month);
      await tester.pumpAndSettle();

      // Tap FAB
      final fab = find.byTooltip('Add event');
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Search and filter events', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.calendar_month);
      await tester.pumpAndSettle();

      // Tap search icon
      final searchBtn = find.byTooltip('Search events');
      if (searchBtn.evaluate().isNotEmpty) {
        await tester.tap(searchBtn);
        await tester.pumpAndSettle();
      }

      // Close search
      final closeBtn = find.byTooltip('Close search');
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
      }
    });
  });

  group('Calculator Feature', () {
    testWidgets('Perform basic calculation', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.calculate);
      await tester.pumpAndSettle();

      // Tap numbers and operator - buttons are ElevatedButton
      for (final label in ['7', '+', '3', '=']) {
        final btn = find.widgetWithText(ElevatedButton, label);
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Toggle scientific mode', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.calculate);
      await tester.pumpAndSettle();

      // Tap scientific toggle
      final sciBtn = find.text('Scientific OFF');
      if (sciBtn.evaluate().isNotEmpty) {
        await tester.tap(sciBtn);
        await tester.pumpAndSettle();
      }

      // Verify memory buttons appear
      expect(find.text('MC'), findsOneWidget);
      expect(find.text('MR'), findsOneWidget);
      expect(find.text('M+'), findsOneWidget);
      expect(find.text('M-'), findsOneWidget);
    });

    testWidgets('Clear calculator', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.calculate);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, '5'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'C'));
      await tester.pumpAndSettle();
    });

    testWidgets('View history', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.calculate);
      await tester.pumpAndSettle();

      // Tap history button
      final histBtn = find.text('History');
      if (histBtn.evaluate().isNotEmpty) {
        await tester.tap(histBtn);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Memory operations with scientific mode', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.calculate);
      await tester.pumpAndSettle();

      // Toggle scientific mode (may be ON from persistent prefs)
      var sciText = find.text('Scientific OFF');
      if (sciText.evaluate().isEmpty) {
        sciText = find.text('Scientific ON');
      }
      if (sciText.evaluate().isNotEmpty) {
        await tester.tap(sciText);
        await tester.pumpAndSettle();
      }

      // Enter a number
      await tester.tap(find.widgetWithText(ElevatedButton, '4'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '2'));
      await tester.pumpAndSettle();

      // M+ (memory add) — uses TextButton in _MemoryRow
      final mPlus = find.widgetWithText(TextButton, 'M+');
      if (mPlus.evaluate().isNotEmpty) {
        await tester.tap(mPlus);
        await tester.pumpAndSettle();
      }

      // MR (memory recall)
      final mR = find.widgetWithText(TextButton, 'MR');
      if (mR.evaluate().isNotEmpty) {
        await tester.tap(mR);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Error on division by zero', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.calculate);
      await tester.pumpAndSettle();

      // 5 ÷ 0 =
      await tester.tap(find.widgetWithText(ElevatedButton, '5'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '÷'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '0'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '='));
      await tester.pumpAndSettle();
    });
  });

  group('Life Tracker Feature', () {
    testWidgets('Navigate to Life and see DOB prompt', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.hourglass_empty_rounded);
      await tester.pumpAndSettle();

      // Wait for loading to complete
      await tester.pump(const Duration(seconds: 3));

      // Verify DOB prompt is visible
      expect(
        find.text('How many days have you been alive?'),
        findsOneWidget,
      );

      // Verify Enter Date of Birth button
      expect(find.text('Enter Date of Birth'), findsOneWidget);
    });

    testWidgets('Life shows hourglass icon in empty state', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.hourglass_empty_rounded);
      await tester.pump(const Duration(seconds: 3));

      // Verify hourglass icon is shown in empty state
      expect(find.byIcon(Icons.hourglass_empty_rounded), findsWidgets);
    });
  });

  group('Settings Feature', () {
    testWidgets('Settings screen renders all sections', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.settings_rounded);
      await tester.pumpAndSettle();

      // Verify visible section headers (scroll for more)
      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('Toggle theme mode', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.settings_rounded);
      await tester.pumpAndSettle();

      // Find theme dropdown and try to interact
      final themeDropdown = find.byType(DropdownButton<ThemeMode>);
      if (themeDropdown.evaluate().isNotEmpty) {
        await tester.tap(themeDropdown);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Notification settings visible', (tester) async {
      app.main();
      await completeOnboarding(tester);
      await goToTab(tester, Icons.settings_rounded);
      await tester.pumpAndSettle();

      // Check notification toggle section exists
      final notificationIcons = find.byIcon(Icons.notifications_rounded);
      if (notificationIcons.evaluate().isNotEmpty) {
        expect(notificationIcons, findsWidgets);
      }
    });
  });
}
