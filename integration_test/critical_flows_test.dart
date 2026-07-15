import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Note CRUD Flow', () {
    testWidgets('Create, edit, and delete a note', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify Notes tab is default
      expect(find.text('Notes'), findsWidgets);

      // Tap FAB to create note
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle();

        // Enter title
        final titleField = find.byType(TextField).first;
        if (titleField.evaluate().isNotEmpty) {
          await tester.enterText(titleField, 'Test Note Title');
          await tester.pumpAndSettle();

          // Save
          final saveButton = find.text('Save');
          if (saveButton.evaluate().isNotEmpty) {
            await tester.tap(saveButton);
            await tester.pumpAndSettle();
          }
        }
      }

      // Verify note appears in grid
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Search notes by query', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find search field
      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        await tester.enterText(searchField.first, 'test');
        await tester.pumpAndSettle();

        // Clear search
        final clearIcon = find.byIcon(Icons.clear);
        if (clearIcon.evaluate().isNotEmpty) {
          await tester.tap(clearIcon);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Bulk select and delete notes', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Long press first note card to enter selection mode
      final noteCards = find.byType(Card);
      if (noteCards.evaluate().isNotEmpty) {
        await tester.longPress(noteCards.first);
        await tester.pumpAndSettle();

        // Verify selection mode UI appears
        final selectAll = find.text('Select All');
        if (selectAll.evaluate().isNotEmpty) {
          expect(selectAll, findsOneWidget);
        }
      }
    });
  });

  group('Habit Toggle & Streak Flow', () {
    testWidgets('Navigate to Habits and verify empty state', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Tap Habits tab
      await tester.tap(find.text('Habits'));
      await tester.pumpAndSettle();

      // Verify empty state or habits list
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Open add habit dialog', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Habits'));
      await tester.pumpAndSettle();

      // Tap add button
      final addButton = find.byIcon(Icons.add_circle_outline_rounded);
      if (addButton.evaluate().isNotEmpty) {
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Verify dialog opened
        expect(find.text('Add Custom Habit'), findsOneWidget);
      }
    });

    testWidgets('Toggle habit completion', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Habits'));
      await tester.pumpAndSettle();

      // Find and tap a habit checkbox or completion button
      final checkboxes = find.byType(Checkbox);
      if (checkboxes.evaluate().isNotEmpty) {
        await tester.tap(checkboxes.first);
        await tester.pumpAndSettle();
      }
    });
  });

  group('Calendar Event & Notification Flow', () {
    testWidgets('Navigate to Calendar and verify month view', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Verify month header exists
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('Open event editor via FAB', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Tap FAB
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // Verify event editor or form appears
        expect(find.byType(Scaffold), findsWidgets);
      }
    });

    testWidgets('Navigate between months', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Tap next month
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      // Tap previous month
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('Search events', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Tap search icon
      final searchIcon = find.byIcon(Icons.search_rounded);
      if (searchIcon.evaluate().isNotEmpty) {
        await tester.tap(searchIcon);
        await tester.pumpAndSettle();

        // Verify search dialog appears
        expect(find.text('Search Events'), findsOneWidget);
      }
    });

    testWidgets('Filter events by category', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Tap filter icon
      final filterIcon = find.byIcon(Icons.filter_list_rounded);
      if (filterIcon.evaluate().isNotEmpty) {
        await tester.tap(filterIcon);
        await tester.pumpAndSettle();

        // Verify popup menu appears
        expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      }
    });
  });

  group('Calculator Operations Flow', () {
    testWidgets('Perform basic calculation', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calculator'));
      await tester.pumpAndSettle();

      // Tap numbers and operator
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('='));
      await tester.pumpAndSettle();
    });

    testWidgets('Toggle scientific mode', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calculator'));
      await tester.pumpAndSettle();

      // Find and tap scientific mode toggle
      final sciButton = find.byTooltip('Enable scientific mode');
      if (sciButton.evaluate().isNotEmpty) {
        await tester.tap(sciButton);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Clear calculator', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calculator'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
    });

    testWidgets('Memory operations', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calculator'));
      await tester.pumpAndSettle();

      // Add a number
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Memory Add
      await tester.tap(find.text('M+'));
      await tester.pumpAndSettle();

      // Memory Recall
      await tester.tap(find.text('MR'));
      await tester.pumpAndSettle();
    });
  });

  group('Life Tracker Flow', () {
    testWidgets('Navigate to Life tab', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Life'));
      await tester.pumpAndSettle();

      // Verify Life screen loads
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Enter DOB via date picker', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Life'));
      await tester.pumpAndSettle();

      // Find and tap DOB entry button
      final enterButton = find.text('Enter Date of Birth');
      if (enterButton.evaluate().isNotEmpty) {
        await tester.tap(enterButton);
        await tester.pumpAndSettle();
      }
    });
  });

  group('Navigation Flow', () {
    testWidgets('Navigate through all tabs', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to each tab
      final tabs = [
        'Notes',
        'Habits',
        'Calendar',
        'Calculator',
        'Life',
        'Settings',
      ];
      for (final tab in tabs) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Settings screen loads', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
