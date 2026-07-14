import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../database.dart';
import '../utils/snackbar_utils.dart';
import '../features/settings_provider.dart';
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
        centerTitle: true,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _AppearanceSection(),
          const SizedBox(height: 24),
          _NotificationsSection(),
          const SizedBox(height: 24),
          _DataSection(),
          const SizedBox(height: 24),
          const _LifeTrackerSection(),
          const SizedBox(height: 24),
          _CalculatorSection(),
          const SizedBox(height: 24),
          _AboutSection(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    if (settings.loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(icon: Icons.palette_rounded, title: 'Appearance'),
              SizedBox(height: 16),
              Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(icon: Icons.palette_rounded, title: 'Appearance'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.brightness_6_rounded),
              title: const Text('Theme'),
              subtitle: const Text('Choose light, dark, or system default'),
              trailing: DropdownButton<ThemeMode>(
                value: settings.themeMode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setThemeMode(value);
                    showSuccessSnackBar(context, 'Theme updated');
                  }
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.color_lens_rounded),
              title: const Text('Color Seed'),
              subtitle: const Text('Change the app accent color'),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: settings.colorSeed,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outline, width: 2),
                ),
              ),
              onTap: () => _showColorPicker(context, settings),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.calendar_view_week_rounded),
              title: const Text('Week starts Monday'),
              subtitle: const Text('Calendar week starts on Monday instead of Sunday'),
              value: settings.weekStartsMonday,
              onChanged: (value) {
                settings.setWeekStartsMonday(value);
                showSuccessSnackBar(context, value ? 'Week starts Monday' : 'Week starts Sunday');
              },
            ),
            const Divider(height: 24),
            ListTile(
              leading: Icon(Icons.restart_alt_rounded, color: theme.colorScheme.error),
              title: Text('Reset All Settings', style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Restore all settings to defaults'),
              onTap: () => _confirmResetSettings(context, settings),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetSettings(BuildContext context, SettingsProvider settings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('This will reset all settings to their default values. Your data will not be affected.'),
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
      await settings.resetToDefaults();
      if (context.mounted) showSuccessSnackBar(context, 'Settings reset to defaults');
    }
  }

  void _showColorPicker(BuildContext context, SettingsProvider settings) {
    final theme = Theme.of(context);
    final colors = [
      Colors.deepPurple, Colors.purple, Colors.blue, Colors.lightBlue,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.red, Colors.pink, Colors.indigo, Colors.cyan,
      Colors.brown, Colors.blueGrey,
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Accent Color', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.wallpaper_rounded, color: theme.colorScheme.primary),
                title: const Text('Default Accent Color', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Reset to system default purple accent'),
                onTap: () {
                  settings.setColorSeed(Colors.deepPurple);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Custom Palette', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: colors.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (ctx, index) {
                  final color = colors[index];
                  final isSelected = settings.colorSeed == color;
                  return GestureDetector(
                    onTap: () {
                      settings.setColorSeed(color);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)]
                            : null,
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                          width: isSelected ? 3 : 0,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white, size: 20)
                          : null,
                    ),
                  );
                },
              ),
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
    final settings = context.watch<SettingsProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(icon: Icons.notifications_rounded, title: 'Notifications'),
            const SizedBox(height: 16),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_rounded),
              title: const Text('Enable Notifications'),
              subtitle: const Text('Receive habit reminders and event alerts'),
              value: settings.notificationsEnabled,
              onChanged: (value) async {
                if (value) {
                  final status = await Permission.notification.request();
                  if (status.isDenied || status.isPermanentlyDenied) {
                    if (context.mounted) {
                      showErrorSnackBar(context, 'Notification permission denied. Enable in system settings.');
                    }
                    return;
                  }
                }
                settings.setNotificationsEnabled(value);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.alarm_rounded),
              title: const Text('Habit Reminders'),
              subtitle: const Text('Get notified at habit reminder times'),
              value: settings.habitRemindersEnabled,
              onChanged: settings.setHabitRemindersEnabled,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.event_rounded),
              title: const Text('Event Reminders'),
              subtitle: const Text('Get notified before calendar events'),
              value: settings.eventRemindersEnabled,
              onChanged: settings.setEventRemindersEnabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _DataSection extends StatefulWidget {
  @override
  State<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<_DataSection> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(icon: Icons.folder_rounded, title: 'Data Management'),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
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
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    setState(() => _loading = true);
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

      setState(() => _loading = false);

      await Share.share(
        jsonString,
        subject: 'Personal App Backup - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      );

      if (context.mounted) {
        showSuccessSnackBar(context, 'Data exported successfully');
      }
    } catch (e) {
      setState(() => _loading = false);
      debugLog('Export failed: $e');
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to export data');
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final content = utf8.decode(file.bytes!);

      final data = jsonDecode(content) as Map<String, dynamic>;

      if (data['version'] == null) {
        setState(() => _loading = false);
        throw const FormatException('Invalid backup file');
      }

      final db = await AppDatabase.instance.database;
      await db.transaction((txn) async {
        await txn.delete('notes');
        await txn.delete('calendar_events');
        await txn.delete('calculator_history');
        await txn.delete('habit_logs');
        await txn.delete('habits');
        await txn.delete('settings');

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

      setState(() => _loading = false);

      if (context.mounted) {
        context.read<NotesProvider>().load();
        context.read<CalendarProvider>().load();
        context.read<CalculatorProvider>().loadHistory();
        context.read<HabitsProvider>().load();
        context.read<LifeProvider>().loadDOB();
        await context.read<SettingsProvider>().reload();
        if (context.mounted) {
          showSuccessSnackBar(context, 'Data imported successfully');
        }
      }
    } catch (e) {
      setState(() => _loading = false);
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

    final deleteController = TextEditingController();
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are You Absolutely Sure?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will permanently delete ALL your data.'),
            const SizedBox(height: 16),
            const Text('Type DELETE to confirm:'),
            const SizedBox(height: 8),
            TextField(
              controller: deleteController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Type DELETE here',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, deleteController.text.trim() == 'DELETE'),
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (doubleConfirmed != true || !context.mounted) return;

    setState(() => _loading = true);
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

      final now = DateTime.now().toIso8601String();
      await db.insert('habits', {'name': 'Bathing', 'icon': 'bathtub', 'created_at': now});
      await db.insert('habits', {'name': 'Playing', 'icon': 'sports_esports', 'created_at': now});
      await db.insert('habits', {'name': 'Exercise', 'icon': 'fitness_center', 'created_at': now});

      setState(() => _loading = false);

      if (context.mounted) {
        context.read<NotesProvider>().load();
        context.read<CalendarProvider>().load();
        context.read<CalculatorProvider>().loadHistory();
        context.read<HabitsProvider>().load();
        context.read<LifeProvider>().loadDOB();
        await context.read<SettingsProvider>().reload();
        if (context.mounted) {
          showSuccessSnackBar(context, 'All data cleared');
        }
      }
    } catch (e) {
      setState(() => _loading = false);
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

    final children = <Widget>[
      const _SectionHeader(icon: Icons.favorite_rounded, title: 'Life Tracker'),
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
      ],
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

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
    final settings = context.watch<SettingsProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(icon: Icons.calculate_rounded, title: 'Calculator'),
            const SizedBox(height: 16),
            SwitchListTile(
              secondary: const Icon(Icons.functions_rounded),
              title: const Text('Scientific Mode'),
              subtitle: const Text('Show advanced functions (sin, cos, log, π, e, etc.)'),
              value: settings.scientificMode,
              onChanged: settings.setScientificMode,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.content_copy_rounded),
              title: const Text('Copy Result on Tap'),
              subtitle: const Text('Tap result to copy to clipboard'),
              value: settings.copyOnTap,
              onChanged: settings.setCopyOnTap,
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
      await context.read<CalculatorProvider>().clearHistory();
    }
  }
}

class _AboutSection extends StatefulWidget {
  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
    } catch (_) {
      if (mounted) setState(() => _version = '1.0.0+1');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(icon: Icons.info_outline_rounded, title: 'About'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.info_rounded),
              title: const Text('Version'),
              subtitle: Text(_version.isEmpty ? 'Loading...' : _version),
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('Source Code'),
              subtitle: const Text('github.com/kssaichandan/PERSONAL-APP'),
              onTap: () async {
                final uri = Uri.parse('https://github.com/kssaichandan/PERSONAL-APP');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  showErrorSnackBar(context, 'Could not open browser');
                }
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
