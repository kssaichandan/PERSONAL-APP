import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../database.dart';
import '../utils/snackbar_utils.dart';
import 'notes.dart';
import 'habits.dart';
import 'calendar.dart';
import 'calculator.dart';
import 'life.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AppearanceSection(),
          const SizedBox(height: 24),
          _NotificationsSection(),
          const SizedBox(height: 24),
          _DataSection(),
          const SizedBox(height: 24),
          _LifeTrackerSection(),
          const SizedBox(height: 24),
          _CalculatorSection(),
          const SizedBox(height: 24),
          _AboutSection(),
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.brightness_6_rounded),
              title: const Text('Theme'),
              subtitle: const Text('Choose light, dark, or system default'),
              trailing: DropdownButton<ThemeMode>(
                value: ThemeMode.system,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                ],
                onChanged: (value) {
                  // TODO: Implement theme persistence
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.color_lens_rounded),
              title: const Text('Color Seed'),
              subtitle: const Text('Change the app accent color'),
              onTap: () => _showColorPicker(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    final theme = Theme.of(context);
    final colors = [
      Colors.deepPurple, Colors.blue, Colors.teal, Colors.green,
      Colors.orange, Colors.red, Colors.pink, Colors.indigo,
      Colors.cyan, Colors.amber, Colors.lime, Colors.brown,
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Color', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((color) => GestureDetector(
                onTap: () {
                  // TODO: Save color preference
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outline, width: 2),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifications', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_rounded),
              title: const Text('Enable Notifications'),
              subtitle: const Text('Receive habit reminders and event alerts'),
              value: true, // TODO: Read from settings
              onChanged: (value) {
                // TODO: Save to settings
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.alarm_rounded),
              title: const Text('Habit Reminders'),
              subtitle: const Text('Get notified at habit reminder times'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              secondary: const Icon(Icons.event_rounded),
              title: const Text('Event Reminders'),
              subtitle: const Text('Get notified before calendar events'),
              value: true,
              onChanged: (value) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _DataSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data Management', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Export All Data'),
              subtitle: const Text('Download JSON backup of notes, habits, events, calculator history, and life data'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _exportData(context),
            ),
            ListTile(
              leading: const Icon(Icons.upload_rounded),
              title: const Text('Import Data'),
              subtitle: const Text('Restore from a previously exported JSON file'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _importData(context),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
              title: Text('Clear All Data', style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Permanently delete all notes, habits, events, and history'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _confirmClearAllData(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final db = await AppDatabase.instance.database;
      
      final notes = await db.query('notes');
      final events = await db.query('calendar_events');
      final calcHistory = await db.query('calculator_history');
      final habits = await db.query('habits');
      final habitLogs = await db.query('habit_logs');
      final settings = await db.query('settings');

      final exportData = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'notes': notes,
        'calendar_events': events,
        'calculator_history': calcHistory,
        'habits': habits,
        'habit_logs': habitLogs,
        'settings': settings,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      await Share.share(
        jsonString,
        subject: 'Personal App Backup - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        mimeType: 'application/json',
      );
      
      if (context.mounted) {
        showSuccessSnackBar(context, 'Data exported successfully');
      }
    } catch (e) {
      debugLog('Export failed: $e');
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to export data');
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      final content = file.bytes != null 
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();
      
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      // Validate structure
      if (data['version'] == null) {
        throw FormatException('Invalid backup file');
      }
      
      final db = await AppDatabase.instance.database;
      await db.transaction((txn) async {
        // Clear existing data
        await txn.delete('notes');
        await txn.delete('calendar_events');
        await txn.delete('calculator_history');
        await txn.delete('habit_logs');
        await txn.delete('habits');
        await txn.delete('settings');
        
        // Insert imported data
        for (final note in (data['notes'] as List? ?? [])) {
          await txn.insert('notes', Map<String, dynamic>.from(note));
        }
        for (final event in (data['calendar_events'] as List? ?? [])) {
          await txn.insert('calendar_events', Map<String, dynamic>.from(event));
        }
        for (final calc in (data['calculator_history'] as List? ?? [])) {
          await txn.insert('calculator_history', Map<String, dynamic>.from(calc));
        }
        for (final habit in (data['habits'] as List? ?? [])) {
          await txn.insert('habits', Map<String, dynamic>.from(habit));
        }
        for (final log in (data['habit_logs'] as List? ?? [])) {
          await txn.insert('habit_logs', Map<String, dynamic>.from(log));
        }
        for (final setting in (data['settings'] as List? ?? [])) {
          await txn.insert('settings', Map<String, dynamic>.from(setting));
        }
      });
      
      // Reload all providers
      if (context.mounted) {
        context.read<NotesProvider>().load();
        context.read<CalendarProvider>().load();
        context.read<CalculatorProvider>().loadHistory();
        context.read<HabitsProvider>().load();
        context.read<LifeProvider>().loadDOB();
        showSuccessSnackBar(context, 'Data imported successfully');
      }
    } catch (e) {
      debugLog('Import failed: $e');
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to import: ${e.toString()}');
      }
    }
  }

  Future<void> _confirmClearAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will permanently delete ALL your notes, habits, events, calculator history, and settings. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !context.mounted) return;
    
    // Double confirmation
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are You Absolutely Sure?'),
        content: const Text('Type "DELETE" to confirm.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ],
      ),
    );
    
    if (doubleConfirmed != true || !context.mounted) return;
    
    try {
      final db = await AppDatabase.instance.database;
      await db.transaction((txn) async {
        await txn.delete('notes');
        await txn.delete('calendar_events');
        await txn.delete('calculator_history');
        await txn.delete('habit_logs');
        await txn.delete('habits');
        await txn.delete('settings');
      });
      
      // Re-add default habits
      final now = DateTime.now().toIso8601String();
      await db.insert('habits', {'name': 'Bathing', 'icon': 'bathtub', 'created_at': now});
      await db.insert('habits', {'name': 'Playing', 'icon': 'sports_esports', 'created_at': now});
      await db.insert('habits', {'name': 'Exercise', 'icon': 'fitness_center', 'created_at': now});
      
      if (context.mounted) {
        context.read<NotesProvider>().load();
        context.read<CalendarProvider>().load();
        context.read<CalculatorProvider>().loadHistory();
        context.read<HabitsProvider>().load();
        context.read<LifeProvider>().loadDOB();
        showSuccessSnackBar(context, 'All data cleared');
      }
    } catch (e) {
      debugLog('Clear data failed: $e');
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to clear data');
      }
    }
  }
}

class _LifeTrackerSection extends StatelessWidget {
  const _LifeTrackerSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<LifeProvider>();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Life Tracker', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (provider.dob == null) ...[
              Text('Set your date of birth to enable life tracking', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _pickDate(context, provider),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Enter Date of Birth'),
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.cake_rounded),
                title: const Text('Date of Birth'),
                subtitle: Text(DateFormat('MMMM d, yyyy').format(provider.dob!)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _pickDate(context, provider),
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Life Expectancy'),
                subtitle: Text('${provider.lifeExpectancy} years (default: 80)'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showLifeExpectancyDialog(context, provider),
              ),
              if (provider.biometricsAvailable != false)
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_rounded),
                  title: const Text('Biometric Lock'),
                  subtitle: const Text('Require fingerprint/face ID to view Life Tracker'),
                  value: provider.biometricEnabled,
                  onChanged: (value) => provider.setBiometricEnabled(value, context),
                ),
              if (provider.biometricsAvailable == false)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Biometric authentication not available on this device',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ListTile(
                leading: Icon(Icons.delete_rounded, color: theme.colorScheme.error),
                title: Text('Reset Life Tracker', style: TextStyle(color: theme.colorScheme.error)),
                subtitle: const Text('Remove your date of birth and start over'),
                onTap: () => _confirmReset(context, provider),
              ),
                    leading: Icon(Icons.delete_rounded, color: theme.colorScheme.error),
                    title: Text('Reset Life Tracker', style: TextStyle(color: theme.colorScheme.error)),
                    subtitle: const Text('Remove your date of birth and start over'),
                    onTap: () => _confirmReset(context, provider),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

  Future<void> _pickDate(BuildContext context, LifeProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.dob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && context.mounted) {
      await provider.saveDOB(picked, context);
    }
  }

  Future<void> _showLifeExpectancyDialog(BuildContext context, LifeProvider provider) async {
    final controller = TextEditingController(text: provider.lifeExpectancy.toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Life Expectancy'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Expected years',
            border: OutlineInputBorder(),
            helperText: 'Used for progress meter calculation',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final years = int.tryParse(controller.text);
              if (years != null && years > 0 && years <= 120) {
                provider.setLifeExpectancy(years, context);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, LifeProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Life Tracker'),
        content: const Text('This will remove your date of birth and all life metrics. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await provider.resetDOB(context);
    }
  }
}

class _CalculatorSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calculator', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SwitchListTile(
              secondary: const Icon(Icons.functions_rounded),
              title: const Text('Scientific Mode'),
              subtitle: const Text('Show advanced functions (sin, cos, log, π, e, etc.)'),
              value: false, // TODO: Read from settings
              onChanged: (value) {
                // TODO: Save to settings
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.content_copy_rounded),
              title: const Text('Copy Result on Tap'),
              subtitle: const Text('Tap result to copy to clipboard'),
              value: true,
              onChanged: (value) {},
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded),
              title: const Text('Clear History'),
              subtitle: const Text('Delete all calculator history entries'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _confirmClearHistory(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Calculator History'),
        content: const Text('Delete all calculation history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<CalculatorProvider>().clearHistory(context);
    }
  }
}

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.info_rounded),
              title: const Text('Version'),
              subtitle: const Text('1.0.0+1'),
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('Source Code'),
              subtitle: const Text('github.com/kssaichandan/PERSONAL-APP'),
              onTap: () {
                // TODO: Launch URL
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_rounded),
              title: const Text('Licenses'),
              subtitle: const Text('View open source licenses'),
              onTap: () {
                showLicensePage(context: context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.school_rounded),
              title: const Text('Show Tutorial'),
              subtitle: const Text('Replay the onboarding tutorial'),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_complete_v1', false);
                if (context.mounted) {
                  showSuccessSnackBar(context, 'Tutorial will show on next app launch');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}