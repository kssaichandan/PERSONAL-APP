import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../database.dart';
import '../utils/snackbar_utils.dart';
import '../features/settings_provider.dart';
import '../features/onboarding.dart';
import 'notes.dart';
import 'habits.dart';
import 'calendar.dart';
import 'calculator.dart';
import 'life.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Settings', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _AppearanceSection(),
            const SizedBox(height: 16),
            _NotificationsSection(),
            const SizedBox(height: 16),
            _DataSection(),
            const SizedBox(height: 16),
            const _LifeTrackerSection(),
            const SizedBox(height: 16),
            _CalculatorSection(),
            const SizedBox(height: 16),
            _AboutSection(),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    if (settings.loading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(icon: Icons.palette_rounded, title: 'Appearance'),
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
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
            const _SectionHeader(
              icon: Icons.palette_rounded,
              title: 'Appearance',
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.brightness_6_rounded),
              title: const Text('Theme'),
              subtitle: const Text('Choose light, dark, or follow system'),
              trailing: DropdownButton<ThemeMode>(
                value: settings.themeMode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    HapticFeedback.selectionClick();
                    settings.setThemeMode(value);
                    String modeName;
                    switch (value) {
                      case ThemeMode.light:
                        modeName = 'Light';
                        break;
                      case ThemeMode.dark:
                        modeName = 'Dark';
                        break;
                      case ThemeMode.system:
                        modeName = 'System';
                        break;
                    }
                    showSuccessSnackBar(context, '$modeName theme applied');
                  }
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.color_lens_rounded),
              title: const Text('Accent Color'),
              subtitle: const Text('Choose the app accent color'),
              trailing: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: settings.colorSeed,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                _showColorPicker(context, settings);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.calendar_view_week_rounded),
              title: const Text('Week starts Monday'),
              subtitle: const Text(
                'Calendar week starts on Monday instead of Sunday',
              ),
              value: settings.weekStartsMonday,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                settings.setWeekStartsMonday(value);
                showSuccessSnackBar(
                  context,
                  value ? 'Week starts Monday' : 'Week starts Sunday',
                );
              },
            ),
            const Divider(height: 24),
            ListTile(
              leading: Icon(
                Icons.restart_alt_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Reset All Settings',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text('Restore all settings to defaults'),
              onTap: () {
                HapticFeedback.selectionClick();
                _confirmResetSettings(context, settings);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetSettings(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reset All Settings'),
            content: const Text(
              'This will reset all settings to their default values. Your data will not be affected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      await settings.resetToDefaults();
      if (context.mounted) {
        showSuccessSnackBar(context, 'Settings reset to defaults');
      }
    }
  }

  void _showColorPicker(BuildContext context, SettingsProvider settings) {
    final theme = Theme.of(context);
    final colors = [
      Colors.blue,
      Colors.indigo,
      Colors.teal,
      Colors.cyan,
      Colors.green,
      Colors.lightGreen,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.brown,
      Colors.blueGrey,
      Colors.lightBlue,
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Accent Color',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.wallpaper_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(
                    'Default Accent Color',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Reset to default blue accent',
                  ),
                  onTap: () async {
                     HapticFeedback.selectionClick();
                     await settings.setColorSeed(Colors.blue);
                     if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                   },
                 ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Color Palette',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: colors.length + 1,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                  itemBuilder: (gridCtx, index) {
                    if (index == colors.length) {
                       return GestureDetector(
                         onTap: () async {
                           HapticFeedback.selectionClick();
                           final color = await showDialog<Color>(
                             context: sheetCtx,
                             builder: (dialogCtx) => _CustomColorPicker(
                               initialColor: settings.colorSeed,
                             ),
                           );
                           if (color != null && sheetCtx.mounted) {
                             await settings.setColorSeed(color);
                             if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                           }
                         },
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.outline,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.palette_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      );
                    }
                    final color = colors[index];
                    final isSelected =
                        settings.colorSeed.toARGB32() == color.toARGB32();
                    return GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await settings.setColorSeed(color);
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                  child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      spreadRadius: 3,
                                    ),
                                  ]
                                  : null,
                          border: Border.all(
                            color:
                                isSelected
                                    ? theme.colorScheme.onSurface
                                    : Colors.transparent,
                            width: isSelected ? 3 : 0,
                          ),
                        ),
                        child:
                            isSelected
                                ? Icon(
                                  Icons.check,
                                  color:
                                      color.computeLuminance() > 0.5
                                          ? Colors.black87
                                          : Colors.white,
                                  size: 20,
                                )
                                : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _CustomColorPicker extends StatefulWidget {
  final Color initialColor;
  const _CustomColorPicker({required this.initialColor});

  @override
  State<_CustomColorPicker> createState() => _CustomColorPickerState();
}

class _CustomColorPickerState extends State<_CustomColorPicker> {
  late HSVColor _hsv;
  final _hexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hexController.text = widget.initialColor
        .toARGB32()
        .toRadixString(16)
        .substring(2)
        .toUpperCase();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateFromHSV(HSVColor hsv) {
    setState(() {
      _hsv = hsv;
      final hex = hsv
          .toColor()
          .toARGB32()
          .toRadixString(16)
          .substring(2)
          .toUpperCase();
      _hexController.text = hex;
    });
  }

  void _updateFromHex(String hex) {
    if (hex.length == 6) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) {
        final color = Color(0xFF000000 | value);
        setState(() {
          _hsv = HSVColor.fromColor(color);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    final theme = Theme.of(context);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pick a Color',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline, width: 2),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onPanUpdate: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                final offset = details.localPosition;
                final dx = (offset.dx / (box.size.width - 40)).clamp(0.0, 1.0);
                final dy = (offset.dy / 200).clamp(0.0, 1.0);
                _updateFromHSV(_hsv.withSaturation(dx).withValue(1.0 - dy));
              },
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: CustomPaint(
                  painter: _SVOverlayPainter(_hsv.hue),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _hsv.hue,
              min: 0,
              max: 360,
              onChanged: (v) => _updateFromHSV(_hsv.withHue(v)),
              activeColor: color,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    decoration: const InputDecoration(
                      hintText: 'HEX',
                      prefixText: '#',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                    onChanged: _updateFromHex,
                    onSubmitted: (_) => Navigator.pop(context, color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, color),
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SVOverlayPainter extends CustomPainter {
  final double hue;
  _SVOverlayPainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    for (double i = 0; i <= 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      final y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SVOverlayPainter old) => old.hue != hue;
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
            const _SectionHeader(
              icon: Icons.notifications_rounded,
              title: 'Notifications',
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_rounded),
              title: const Text('Enable Notifications'),
              subtitle: const Text('Receive habit reminders and event alerts'),
              value: settings.notificationsEnabled,
              onChanged: (value) async {
                HapticFeedback.selectionClick();
                if (value) {
                  final granted =
                      await settings.requestNotificationPermissions();
                  if (!granted) {
                    if (context.mounted) {
                      showErrorSnackBar(
                        context,
                        'Notifications are blocked. Enable them in your phone settings.',
                      );
                    }
                    return;
                  }
                }
                await settings.setNotificationsEnabled(value);
                if (context.mounted) {
                  showSuccessSnackBar(
                    context,
                    value ? 'Notifications enabled' : 'Notifications disabled',
                  );
                }
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.alarm_rounded),
              title: const Text('Habit Reminders'),
              subtitle: const Text('Get notified at habit reminder times'),
              value: settings.habitRemindersEnabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                settings.setHabitRemindersEnabled(value);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.event_rounded),
              title: const Text('Event Reminders'),
              subtitle: const Text('Get notified before calendar events'),
              value: settings.eventRemindersEnabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                settings.setEventRemindersEnabled(value);
              },
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
  double? _progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.folder_rounded,
              title: 'Data Management',
            ),
            const SizedBox(height: 8),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    if (_progress != null)
                      Column(
                        children: [
                          LinearProgressIndicator(value: _progress),
                          const SizedBox(height: 8),
                          Text(
                            '${((_progress ?? 0) * 100).round()}%',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      )
                    else
                      const CircularProgressIndicator(),
                  ],
                ),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Export All Data'),
                subtitle: const Text(
                  'Download a JSON backup of all your data',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _exportData(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_rounded),
                title: const Text('Import Data'),
                subtitle: const Text(
                  'Restore from a previously exported backup file',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _importData(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Clear All Data',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text(
                  'Permanently delete all notes, habits, events, and history',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _confirmClearAllData(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    setState(() {
      _loading = true;
      _progress = 0.1;
    });
    try {
      final db = await AppDatabase.instance.database;

      setState(() => _progress = 0.2);
      final notes = await db.query('notes');
      final events = await db.query('calendar_events');
      final calcHistory = await db.query('calculator_history');
      final habits = await db.query('habits');
      final habitLogs = await db.query('habit_logs');
      final settings = await db.query('settings');

      setState(() => _progress = 0.5);

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

      setState(() => _progress = 0.8);

      if (!context.mounted) return;
      final shouldSave = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Export Data'),
              content: const Text(
                'Would you like to save the backup file or share it?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Share'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save to Device'),
                ),
              ],
            ),
      );

      if (!context.mounted) return;

      if (shouldSave == true) {
        String? outputPath = await FilePicker.saveFile(
          dialogTitle: 'Save Backup File',
          fileName:
              'personal_app_backup_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: utf8.encode(jsonString),
        );

        if (outputPath != null && context.mounted) {
          showSuccessSnackBar(context, 'Backup saved successfully');
        }
      } else {
        final filePath =
            '${Directory.systemTemp.path}/personal_app_backup_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
        final file = File(filePath);
        await file.writeAsString(jsonString);

        await Share.shareXFiles(
          [XFile(filePath)],
          subject:
              'Personal App Backup - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        );

        if (!context.mounted) return;
        showSuccessSnackBar(context, 'Data exported successfully');
      }

      setState(() {
        _loading = false;
        _progress = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _progress = null;
      });
      debugLog('Export failed: $e');
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to export data');
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Import Data'),
            content: const Text(
              'This will replace all current data with the imported backup. This action cannot be undone. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() {
      _loading = true;
      _progress = 0.1;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _loading = false;
          _progress = null;
        });
        return;
      }

      setState(() => _progress = 0.2);

      final file = result.files.first;
      final content = utf8.decode(file.bytes!);

      final data = jsonDecode(content) as Map<String, dynamic>;

      if (data['version'] == null) {
        setState(() {
          _loading = false;
          _progress = null;
        });
        throw const FormatException('Invalid backup file');
      }

      setState(() => _progress = 0.3);

      final db = await AppDatabase.instance.database;
      await db.transaction((txn) async {
        await txn.delete('notes');
        await txn.delete('calendar_events');
        await txn.delete('calculator_history');
        await txn.delete('habit_logs');
        await txn.delete('habits');
        await txn.delete('settings');

        final allNotes = data['notes'] as List? ?? [];
        final allEvents = data['calendar_events'] as List? ?? [];
        final allCalc = data['calculator_history'] as List? ?? [];
        final allHabits = data['habits'] as List? ?? [];
        final allLogs = data['habit_logs'] as List? ?? [];
        final allSettings = data['settings'] as List? ?? [];
        final totalRows =
            allNotes.length +
            allEvents.length +
            allCalc.length +
            allHabits.length +
            allLogs.length +
            allSettings.length;
        int processed = 0;

        for (final note in allNotes) {
          await txn.insert('notes', Map<String, dynamic>.from(note));
          processed++;
          if (totalRows > 0) {
            setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
          }
        }
        for (final event in allEvents) {
          await txn.insert(
            'calendar_events',
            Map<String, dynamic>.from(event),
          );
          processed++;
          if (totalRows > 0) {
            setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
          }
        }
        for (final calc in allCalc) {
          await txn.insert(
            'calculator_history',
            Map<String, dynamic>.from(calc),
          );
          processed++;
          if (totalRows > 0) {
            setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
          }
        }
        for (final habit in allHabits) {
          await txn.insert('habits', Map<String, dynamic>.from(habit));
          processed++;
          if (totalRows > 0) {
            setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
          }
        }
        for (final log in allLogs) {
          await txn.insert('habit_logs', Map<String, dynamic>.from(log));
          processed++;
          if (totalRows > 0) {
            setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
          }
        }
        for (final setting in allSettings) {
          await txn.insert('settings', Map<String, dynamic>.from(setting));
          processed++;
          if (totalRows > 0) {
            setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
          }
        }
      });

      setState(() => _progress = 0.9);

      if (!context.mounted) return;
      context.read<NotesProvider>().load();
      context.read<CalendarProvider>().load();
      context.read<CalculatorProvider>().loadHistory();
      context.read<HabitsProvider>().load();
      context.read<LifeProvider>().loadDOB();
      await context.read<SettingsProvider>().reload();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _progress = null;
      });

      if (!context.mounted) return;
      HapticFeedback.mediumImpact();
      showSuccessSnackBar(context, 'Data imported successfully');
    } catch (e) {
      setState(() {
        _loading = false;
        _progress = null;
      });
      debugLog('Import failed: $e');
      if (context.mounted) {
        showErrorSnackBar(context, 'Failed to import: ${e.toString()}');
      }
    }
  }

  Future<void> _confirmClearAllData(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: Icon(
              Icons.warning_rounded,
              color: theme.colorScheme.error,
              size: 32,
            ),
            title: const Text('Clear All Data?'),
            content: const Text(
              'This will permanently delete all your notes, habits, events, calculator history, and settings. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: const Text('Delete All'),
              ),
            ],
          ),
    );

    if (confirmed != true || !context.mounted) return;

    final deleteController = TextEditingController();
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return _DeleteConfirmationDialog(
          controller: deleteController,
          theme: theme,
        );
      },
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

      setState(() => _loading = false);

      if (context.mounted) {
        context.read<NotesProvider>().load();
      }
      if (context.mounted) {
        context.read<CalendarProvider>().load();
      }
      if (context.mounted) {
        context.read<CalculatorProvider>().loadHistory();
      }
      if (context.mounted) {
        context.read<HabitsProvider>().load();
      }
      if (context.mounted) {
        context.read<LifeProvider>().loadDOB();
      }
      if (context.mounted) {
        await context.read<SettingsProvider>().reload();
      }
      if (context.mounted) {
        HapticFeedback.mediumImpact();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                icon: Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  size: 48,
                ),
                title: const Text('Data Cleared'),
                content: const Text(
                  'All data has been successfully cleared. The app is now in a fresh state.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
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

class _DeleteConfirmationDialog extends StatefulWidget {
  final TextEditingController controller;
  final ThemeData theme;

  const _DeleteConfirmationDialog({
    required this.controller,
    required this.theme,
  });

  @override
  State<_DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  bool get _isValid => widget.controller.text.trim() == 'DELETE';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.delete_forever_rounded,
        color: widget.theme.colorScheme.error,
        size: 32,
      ),
      title: const Text('Final Confirmation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This is your final chance to cancel. Type DELETE below to permanently erase all data:',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Type DELETE here',
              errorText:
                  widget.controller.text.isNotEmpty && !_isValid
                      ? 'Type DELETE in all caps'
                      : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _isValid ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: widget.theme.colorScheme.error,
            foregroundColor: widget.theme.colorScheme.onError,
          ),
          child: const Text('Permanently Delete'),
        ),
      ],
    );
  }
}

class _LifeTrackerSection extends StatelessWidget {
  const _LifeTrackerSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<LifeProvider>();

    final children = <Widget>[
      const _SectionHeader(
        icon: Icons.favorite_rounded,
        title: 'Life Tracker',
      ),
      const SizedBox(height: 8),
      if (provider.dob == null) ...[
        Text(
          'Set your date of birth to enable life tracking and see your life progress.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: 'Set date of birth',
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              _pickDate(context, provider);
            },
            icon: const Icon(Icons.calendar_today),
            label: const Text('Set Date of Birth'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ] else ...[
        ListTile(
          leading: const Icon(Icons.cake_rounded),
          title: const Text('Date of Birth'),
          subtitle: Text(DateFormat('MMMM d, yyyy').format(provider.dob!)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            HapticFeedback.selectionClick();
            _pickDate(context, provider);
          },
        ),
        ListTile(
          leading: const Icon(Icons.speed_rounded),
          title: const Text('Life Expectancy'),
          subtitle: Text('${provider.lifeExpectancy} years'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            HapticFeedback.selectionClick();
            _showLifeExpectancyDialog(context, provider);
          },
        ),
        ListTile(
          leading: Icon(
            Icons.delete_rounded,
            color: theme.colorScheme.error,
          ),
          title: Text(
            'Reset Life Tracker',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          subtitle: const Text('Remove your date of birth and start over'),
          onTap: () {
            HapticFeedback.selectionClick();
            _confirmReset(context, provider);
          },
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

  Future<void> _showLifeExpectancyDialog(
    BuildContext context,
    LifeProvider provider,
  ) async {
    final controller = TextEditingController(
      text: provider.lifeExpectancy.toString(),
    );
    await showDialog(
      context: context,
      builder: (ctx) {
        return LifeExpectancyDialog(
          controller: controller,
          initialValue: provider.lifeExpectancy,
          onSave: (years) {
            provider.setLifeExpectancy(years, context);
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _confirmReset(
    BuildContext context,
    LifeProvider provider,
  ) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reset Life Tracker'),
            content: const Text(
              'This will remove your date of birth and all life metrics. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: const Text('Reset'),
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
            const _SectionHeader(
              icon: Icons.calculate_rounded,
              title: 'Calculator',
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: const Icon(Icons.functions_rounded),
              title: const Text('Scientific Mode'),
              subtitle: const Text(
                'Show advanced functions (sin, cos, log, π, e)',
              ),
              value: settings.scientificMode,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                settings.setScientificMode(value);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.content_copy_rounded),
              title: const Text('Copy Result on Tap'),
              subtitle: const Text('Tap the result to copy to clipboard'),
              value: settings.copyOnTap,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                settings.setCopyOnTap(value);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded),
              title: const Text('Clear History'),
              subtitle: const Text('Delete all calculator history entries'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                HapticFeedback.selectionClick();
                _confirmClearHistory(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Clear Calculator History'),
            content: const Text('Delete all calculation history?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: const Text('Clear'),
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
  String? _version;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = '${info.version}+${info.buildNumber}';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _version = '1.0.0+1';
          _loading = false;
        });
      }
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
            const _SectionHeader(
              icon: Icons.info_outline_rounded,
              title: 'About',
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.info_rounded),
              title: const Text('Version'),
              subtitle:
                  _loading
                      ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          const Text('Loading...'),
                        ],
                      )
                      : Text(_version ?? 'Unknown'),
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('Source Code'),
              subtitle: const Text('View project on GitHub'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () async {
                HapticFeedback.selectionClick();
                final uri = Uri.parse(
                  'https://github.com/kssaichandan/PERSONAL-APP',
                );
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
                HapticFeedback.selectionClick();
                showLicensePage(
                  context: context,
                  applicationName: 'Personal App',
                  applicationVersion: _version,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.school_rounded),
              title: const Text('Show Tutorial'),
              subtitle: const Text('Replay the onboarding tutorial'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                HapticFeedback.selectionClick();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('Replay Tutorial'),
                        content: const Text(
                          'This will restart the onboarding tutorial. Continue?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                );
                if (confirmed != true || !context.mounted) return;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_complete_v1', false);
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OnboardingScreen(),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
