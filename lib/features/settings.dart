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
        title: Text('Settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
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

class _SettingsSectionCard extends StatelessWidget {
  final Widget child;

  const _SettingsSectionCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
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
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
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
      return const _SettingsSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(icon: Icons.palette_rounded, title: 'Appearance'),
            SizedBox(height: 16),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    return _SettingsSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.palette_rounded,
            title: 'Appearance',
          ),
          const SizedBox(height: 4),
          
          // Theme Segmented Preview Cards
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'App Theme',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ThemePreviewCard(
                  title: 'Light',
                  mode: ThemeMode.light,
                  icon: Icons.light_mode_rounded,
                  isSelected: settings.themeMode == ThemeMode.light,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    settings.setThemeMode(ThemeMode.light);
                    showSuccessSnackBar(context, 'Light theme applied');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemePreviewCard(
                  title: 'Dark',
                  mode: ThemeMode.dark,
                  icon: Icons.dark_mode_rounded,
                  isSelected: settings.themeMode == ThemeMode.dark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    settings.setThemeMode(ThemeMode.dark);
                    showSuccessSnackBar(context, 'Dark theme applied');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemePreviewCard(
                  title: 'System',
                  mode: ThemeMode.system,
                  icon: Icons.brightness_auto_rounded,
                  isSelected: settings.themeMode == ThemeMode.system,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    settings.setThemeMode(ThemeMode.system);
                    showSuccessSnackBar(context, 'System theme applied');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Masterpiece Accent Color Picker Tile
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: settings.colorSeed.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.palette_rounded, color: settings.colorSeed, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Accent Color Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  'Universal primary app accent',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _showColorPicker(context, settings);
                      },
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('More'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Horizontal Quick Color Palette Strip
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Colors.blue,
                    Colors.indigo,
                    Colors.teal,
                    Colors.cyan,
                    Colors.green,
                    Colors.amber,
                    Colors.orange,
                    Colors.deepOrange,
                    Colors.red,
                    Colors.purple,
                    Colors.pink,
                  ].map((color) {
                    final isSelected = settings.colorSeed.toARGB32() == color.toARGB32();
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          settings.setColorSeed(color);
                          showSuccessSnackBar(context, 'Accent theme updated');
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.onSurface : Colors.transparent,
                              width: isSelected ? 3 : 0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: isSelected ? 0.5 : 0.2),
                                blurRadius: isSelected ? 10 : 4,
                                spreadRadius: isSelected ? 2 : 0,
                              ),
                            ],
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const Divider(height: 16, indent: 4, endIndent: 4),
          
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: const Icon(Icons.calendar_view_week_rounded),
            title: const Text('Week starts Monday', style: TextStyle(fontWeight: FontWeight.w600)),
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
          const Divider(height: 16, indent: 4, endIndent: 4),
          
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(
              Icons.restart_alt_rounded,
              color: theme.colorScheme.error,
            ),
            title: Text(
              'Reset All Settings',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text('Restore all settings to default values'),
            onTap: () {
              HapticFeedback.selectionClick();
              _confirmResetSettings(context, settings);
            },
          ),
        ],
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Icon(Icons.restart_alt_rounded, color: theme.colorScheme.error, size: 36),
        title: const Text('Reset All Settings'),
        content: const Text(
          'This will reset all settings to their default values. Your saved notes and data will not be affected.',
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
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Accent Color Palette',
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                ),
                title: const Text(
                  'Default Accent Color',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Reset to standard Flutter blue'),
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await settings.setColorSeed(Colors.blue);
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'PRESET COLORS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: colors.length + 1,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
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
                            shape: BoxShape.circle,
                            gradient: const SweepGradient(
                              colors: [
                                Colors.red,
                                Colors.yellow,
                                Colors.green,
                                Colors.cyan,
                                Colors.blue,
                                Colors.purple,
                                Colors.red,
                              ],
                            ),
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.colorize_rounded,
                              color: theme.colorScheme.onSurface,
                              size: 18,
                            ),
                          ),
                        ),
                      );
                    }
                    final color = colors[index];
                    final isSelected = settings.colorSeed.toARGB32() == color.toARGB32();
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
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.onSurface : Colors.transparent,
                            width: isSelected ? 3 : 0,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
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

class _ThemePreviewCard extends StatelessWidget {
  final String title;
  final ThemeMode mode;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.title,
    required this.mode,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMockup = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    final bgMockup = isDarkMockup ? theme.colorScheme.surfaceDim : theme.colorScheme.surfaceContainerLow;
    final cardMockup = isDarkMockup ? theme.colorScheme.surfaceContainerLow : theme.colorScheme.surface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // Mini phone screen mockup
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: bgMockup,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDarkMockup ? Colors.white12 : Colors.black12,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 24,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Icon(icon, size: 10, color: theme.colorScheme.primary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: cardMockup,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 12,
                      width: 32,
                      decoration: BoxDecoration(
                        color: cardMockup,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
  final GlobalKey _pickerBoxKey = GlobalKey();

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

  void _handleTouch(Offset globalPosition) {
    final RenderBox? box = _pickerBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localOffset = box.globalToLocal(globalPosition);
    final dx = (localOffset.dx / box.size.width).clamp(0.0, 1.0);
    final dy = (localOffset.dy / box.size.height).clamp(0.0, 1.0);
    _updateFromHSV(_hsv.withSaturation(dx).withValue(1.0 - dy));
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Custom Accent Color',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Color Preview Banner
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '#${_hexController.text}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                    color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2D Saturation & Value Selection Field
            GestureDetector(
              onPanStart: (details) => _handleTouch(details.globalPosition),
              onPanUpdate: (details) => _handleTouch(details.globalPosition),
              onTapDown: (details) => _handleTouch(details.globalPosition),
              child: Container(
                key: _pickerBoxKey,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Base hue color fill
                      Container(
                        color: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                      ),
                      // White saturation overlay (left to right)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.transparent],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      // Black value overlay (bottom to top)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black, Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                      // Interactive Thumb Handle
                      Positioned(
                        left: (_hsv.saturation * 100).clamp(0.0, 100.0) * 2.2, // dynamic calculation display
                        top: ((1.0 - _hsv.value) * 100).clamp(0.0, 100.0) * 1.3,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Multi-stop Rainbow Gradient Hue Slider
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                        Colors.cyan,
                        Colors.blue,
                        Colors.purple,
                        Colors.red,
                      ],
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 0,
                    thumbColor: color,
                    overlayColor: color.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _hsv.hue,
                    min: 0,
                    max: 360,
                    onChanged: (v) => _updateFromHSV(_hsv.withHue(v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // HEX Input Row
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      hintText: 'HEX CODE',
                      prefixText: '# ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    onChanged: _updateFromHex,
                    onSubmitted: (_) => Navigator.pop(context, color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
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

class _NotificationsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final enabled = settings.notificationsEnabled;

    return _SettingsSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: const Icon(Icons.notifications_active_rounded),
            title: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Receive habit reminders and scheduled alerts'),
            value: enabled,
            onChanged: (value) async {
              HapticFeedback.selectionClick();
              if (value) {
                final granted = await settings.requestNotificationPermissions();
                if (!granted) {
                  if (context.mounted) {
                    showErrorSnackBar(
                      context,
                      'Notifications are blocked. Enable them in your device settings.',
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
          const Divider(height: 16, indent: 4, endIndent: 4),

          // Sub-switches with opacity dimming when master notifications are off
          Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  secondary: const Icon(Icons.alarm_rounded),
                  title: const Text('Habit Reminders', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Get notified at your specified habit times'),
                  value: settings.habitRemindersEnabled,
                  onChanged: enabled
                      ? (value) {
                          HapticFeedback.selectionClick();
                          settings.setHabitRemindersEnabled(value);
                        }
                      : null,
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  secondary: const Icon(Icons.event_rounded),
                  title: const Text('Event Reminders', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Get notified before calendar events'),
                  value: settings.eventRemindersEnabled,
                  onChanged: enabled
                      ? (value) {
                          HapticFeedback.selectionClick();
                          settings.setEventRemindersEnabled(value);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
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
    return _SettingsSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.folder_rounded,
            title: 'Data Management',
          ),
          const SizedBox(height: 4),
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
                          'Processing... ${((_progress ?? 0) * 100).round()}%',
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.download_rounded),
              title: const Text('Export All Data', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Download a JSON backup of your notes & history'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                HapticFeedback.selectionClick();
                _exportData(context);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.upload_rounded),
              title: const Text('Import Data', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Restore data from an existing backup file'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                HapticFeedback.selectionClick();
                _importData(context);
              },
            ),
            const SizedBox(height: 12),

            // Dedicated Destructive Action Warning Container
            Material(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Icon(
                  Icons.delete_forever_rounded,
                  color: theme.colorScheme.error,
                  size: 24,
                ),
                title: Text(
                  'Clear All Data',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Permanently delete all app entries and history',
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.error,
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _confirmClearAllData(context);
                },
              ),
            ),
          ],
        ],
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
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          icon: const Icon(Icons.ios_share_rounded, size: 36),
          title: const Text('Export Backup'),
          content: const Text(
            'Would you like to save the backup file directly to device storage or share it?',
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
          fileName: 'personal_app_backup_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json',
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
          subject: 'Personal App Backup - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.primary, size: 36),
        title: const Text('Import Data'),
        content: const Text(
          'This will replace your current data with the imported backup file. This action cannot be undone. Continue?',
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
        throw const FormatException('Invalid backup file structure');
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
          if (totalRows > 0) setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
        }
        for (final event in allEvents) {
          await txn.insert('calendar_events', Map<String, dynamic>.from(event));
          processed++;
          if (totalRows > 0) setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
        }
        for (final calc in allCalc) {
          await txn.insert('calculator_history', Map<String, dynamic>.from(calc));
          processed++;
          if (totalRows > 0) setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
        }
        for (final habit in allHabits) {
          await txn.insert('habits', Map<String, dynamic>.from(habit));
          processed++;
          if (totalRows > 0) setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
        }
        for (final log in allLogs) {
          await txn.insert('habit_logs', Map<String, dynamic>.from(log));
          processed++;
          if (totalRows > 0) setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
        }
        for (final setting in allSettings) {
          await txn.insert('settings', Map<String, dynamic>.from(setting));
          processed++;
          if (totalRows > 0) setState(() => _progress = 0.3 + (0.5 * processed / totalRows));
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Icon(
          Icons.warning_rounded,
          color: theme.colorScheme.error,
          size: 40,
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
      builder: (ctx) => _DeleteConfirmationDialog(
        controller: deleteController,
        theme: theme,
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

      setState(() => _loading = false);

      if (context.mounted) context.read<NotesProvider>().load();
      if (context.mounted) context.read<CalendarProvider>().load();
      if (context.mounted) context.read<CalculatorProvider>().loadHistory();
      if (context.mounted) context.read<HabitsProvider>().load();
      if (context.mounted) context.read<LifeProvider>().loadDOB();
      if (context.mounted) await context.read<SettingsProvider>().reload();

      if (context.mounted) {
        HapticFeedback.heavyImpact();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            icon: Icon(
              Icons.check_circle_rounded,
              color: theme.colorScheme.primary,
              size: 48,
            ),
            title: const Text('Data Cleared'),
            content: const Text(
              'All data has been successfully cleared. The app is now reset.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
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
  State<_DeleteConfirmationDialog> createState() => _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  bool get _isValid => widget.controller.text.trim().toUpperCase() == 'DELETE';

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: Icon(
        Icons.delete_forever_rounded,
        color: widget.theme.colorScheme.error,
        size: 36,
      ),
      title: const Text('Final Confirmation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type DELETE below to permanently erase all stored data:',
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              widget.controller.text = 'DELETE';
              HapticFeedback.selectionClick();
            },
            child: Chip(
              avatar: const Icon(Icons.touch_app_rounded, size: 16),
              label: const Text('Tap to insert "DELETE"'),
              backgroundColor: widget.theme.colorScheme.errorContainer.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              hintText: 'DELETE',
              errorText: widget.controller.text.isNotEmpty && !_isValid
                  ? 'Must match DELETE in all caps'
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
          onPressed: _isValid ? () => Navigator.pop(context, true) : null,
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

    return _SettingsSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.favorite_rounded,
            title: 'Life Tracker',
          ),
          const SizedBox(height: 4),
          if (provider.dob == null) ...[
            Text(
              'Set your date of birth to enable live tracking and metrics.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                _pickDate(context, provider);
              },
              icon: const Icon(Icons.calendar_today_rounded),
              label: const Text('Set Date of Birth'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ] else ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.cake_rounded),
              title: const Text('Date of Birth', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(DateFormat('MMMM d, yyyy').format(provider.dob!)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                HapticFeedback.selectionClick();
                _pickDate(context, provider);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.speed_rounded),
              title: const Text('Life Expectancy', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${provider.lifeExpectancy} years'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                HapticFeedback.selectionClick();
                _showLifeExpectancyDialog(context, provider);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Reset Life Tracker',
                style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Remove date of birth and reset metrics'),
              onTap: () {
                HapticFeedback.selectionClick();
                _confirmReset(context, provider);
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, LifeProvider provider) async {
    final theme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.dob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
          ),
          child: child!,
        );
      },
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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

    return _SettingsSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.calculate_rounded,
            title: 'Calculator',
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: const Icon(Icons.functions_rounded),
            title: const Text('Scientific Mode', style: TextStyle(fontWeight: FontWeight.w600)),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: const Icon(Icons.content_copy_rounded),
            title: const Text('Copy Result on Tap', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Tap result to copy to clipboard'),
            value: settings.copyOnTap,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              settings.setCopyOnTap(value);
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.delete_sweep_rounded),
            title: const Text('Clear Calculator History', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Delete all calculator history entries'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              HapticFeedback.selectionClick();
              _confirmClearHistory(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Clear Calculator History'),
        content: const Text('Delete all calculation history entries?'),
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
    final theme = Theme.of(context);
    return _SettingsSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'About App',
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.info_rounded),
            title: const Text('Version', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: _loading
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading...'),
                    ],
                  )
                : Text(_version ?? '1.0.0+1'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'RELEASE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.code_rounded),
            title: const Text('Source Code', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('View open source code on GitHub'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () async {
              HapticFeedback.selectionClick();
              final uri = Uri.parse(
                'https://github.com/kssaichandan/PERSONAL-APP',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (context.mounted) {
                showErrorSnackBar(context, 'Could not open browser link');
              }
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.article_rounded),
            title: const Text('Licenses', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('View third-party open source licenses'),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.school_rounded),
            title: const Text('Replay Tutorial', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Restart the onboarding walkthrough'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              HapticFeedback.selectionClick();
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  title: const Text('Replay Tutorial'),
                  content: const Text(
                    'This will restart the onboarding tutorial experience. Continue?',
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
    );
  }
}
