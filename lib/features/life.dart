import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database.dart';
import '../utils/snackbar_utils.dart';


class LifeProvider extends ChangeNotifier {
  DateTime? _dob;
  bool _loading = true;
  int _lifeExpectancy = 80;

  DateTime? get dob => _dob;
  bool get loading => _loading;
  int get lifeExpectancy => _lifeExpectancy;

  LifeProvider() {
    Future.microtask(() => loadDOB());
  }

  Future<void> _loadLifeExpectancy() async {
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['life_expectancy'],
      );
      if (maps.isNotEmpty) {
        _lifeExpectancy = int.parse(maps.first['value'] as String);
      }
    } catch (_) {}
  }

  Future<void> setLifeExpectancy(int years, [BuildContext? context]) async {
    if (years < 1 || years > 120) return;
    _lifeExpectancy = years;
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['life_expectancy'],
      );
      if (maps.isEmpty) {
        await db.insert('settings', {
          'key': 'life_expectancy',
          'value': years.toString(),
        });
      } else {
        await db.update(
          'settings',
          {'value': years.toString()},
          where: 'key = ?',
          whereArgs: ['life_expectancy'],
        );
      }
      notifyListeners();
      if (context != null && context.mounted) {
        showSuccessSnackBar(context, 'Life expectancy updated to $years years');
      }
    } catch (e) {
      debugLog('Failed to save life expectancy: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to save life expectancy');
      }
    }
  }

  Future<void> loadDOB() async {
    _loading = true;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['dob'],
      );
      if (maps.isNotEmpty) {
        _dob = DateTime.parse(maps.first['value'] as String);
      } else {
        _dob = null;
      }
      await _loadLifeExpectancy();
    } catch (e) {
      debugLog('Failed to load DOB and settings: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> saveDOB(DateTime date, [BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      final val = DateFormat('yyyy-MM-dd').format(date);
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['dob'],
      );
      if (maps.isEmpty) {
        await db.insert('settings', {'key': 'dob', 'value': val});
      } else {
        await db.update(
          'settings',
          {'value': val},
          where: 'key = ?',
          whereArgs: ['dob'],
        );
      }
      _dob = DateTime(date.year, date.month, date.day);
      notifyListeners();
      if (context != null && context.mounted) {
        showSuccessSnackBar(context, 'Date of birth saved');
      }
    } catch (e) {
      debugLog('Failed to save DOB: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to save date of birth');
      }
    }
  }

  Future<void> resetDOB([BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('settings', where: 'key = ?', whereArgs: ['dob']);
      _dob = null;
      notifyListeners();
      if (context != null && context.mounted) {
        showSuccessSnackBar(context, 'Date of birth reset');
      }
    } catch (e) {
      debugLog('Failed to reset DOB: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to reset date of birth');
      }
    }
  }
}

class LifeScreen extends StatelessWidget {
  const LifeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<LifeProvider>();

    if (provider.loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading your life tracker...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.dob == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Life Journey', style: theme.textTheme.titleLarge),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 96,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'How many days have you been alive?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter your date of birth to see your live life progress, time elapsed, and remaining years.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Semantics(
                    button: true,
                    label: 'Enter date of birth',
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: provider.dob ?? DateTime(2000, 1, 1),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && context.mounted) {
                          await provider.saveDOB(picked, context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size.fromHeight(56),
                      ),
                      icon: const Icon(Icons.calendar_today),
                      label: const Text(
                        'Enter Date of Birth',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final dob = provider.dob!;
    final expectedYears = provider.lifeExpectancy;

    return _LifeScreenContent(
      dob: dob,
      expectedYears: expectedYears,
      provider: provider,
    );
  }
}

class _LifeScreenContent extends StatefulWidget {
  final DateTime dob;
  final int expectedYears;
  final LifeProvider provider;

  const _LifeScreenContent({
    required this.dob,
    required this.expectedYears,
    required this.provider,
  });

  @override
  State<_LifeScreenContent> createState() => _LifeScreenContentState();
}

class _LifeScreenContentState extends State<_LifeScreenContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Life Journey', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed_rounded),
            tooltip: 'Life expectancy',
            onPressed: () {
              HapticFeedback.selectionClick();
              _showLifeExpectancyDialog(context, widget.provider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar_rounded),
            tooltip: 'Change date of birth',
            onPressed: () {
              HapticFeedback.selectionClick();
              _pickDate(context, widget.provider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_backup_restore_rounded),
            tooltip: 'Reset date of birth',
            onPressed: () {
              HapticFeedback.selectionClick();
              _confirmReset(context, widget.provider);
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            final difference = now.difference(widget.dob);
            int years = now.year - widget.dob.year;
            int months = now.month - widget.dob.month;
            int days = now.day - widget.dob.day;
            if (days < 0) {
              months--;
              final prevMonth = DateTime(now.year, now.month, 0);
              days += prevMonth.day;
            }
            if (months < 0) {
              years--;
              months += 12;
            }

            final totalDays = difference.inDays;
            final totalHours = difference.inHours;
            final totalMinutes = difference.inMinutes;
            final totalSeconds = difference.inSeconds;
            final totalExpectedDays = widget.expectedYears * 365.25;
            final lifePercentage = (totalDays / totalExpectedDays) * 100;
            final formattedPercentage = lifePercentage.toStringAsFixed(2);

            final expectedDeathDate = DateTime(
              widget.dob.year + widget.expectedYears,
              widget.dob.month,
              widget.dob.day,
            );
            final remainingDuration = expectedDeathDate.difference(now);
            int remainingYears = expectedDeathDate.year - now.year;
            int remainingMonths = expectedDeathDate.month - now.month;
            int remainingDays = expectedDeathDate.day - now.day;
            if (remainingDays < 0) {
              remainingMonths--;
              final prevMonth = DateTime(
                expectedDeathDate.year,
                expectedDeathDate.month,
                0,
              );
              remainingDays += prevMonth.day;
            }
            if (remainingMonths < 0) {
              remainingYears--;
              remainingMonths += 12;
            }
            if (remainingDuration.isNegative) {
              remainingYears = 0;
              remainingMonths = 0;
              remainingDays = 0;
            }

            final progressColor =
                lifePercentage < 50
                    ? theme.colorScheme.primary
                    : lifePercentage < 80
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.secondary;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'TIME ELAPSED SINCE BIRTH',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _LiveBadge(
                                controller: _pulseController,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        Semantics(
                          label:
                              '$years years, $months months, $days days elapsed since birth',
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$years',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ' yrs  ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '$months',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ' mos  ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '$days',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ' days',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Born on ${DateFormat('MMMM d, yyyy').format(widget.dob)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Life Progress Meter',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$formattedPercentage%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: progressColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (lifePercentage / 100).clamp(0.0, 1.0),
                            minHeight: 14,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progressColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Based on a life expectancy of ${widget.expectedYears} years.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You have lived $formattedPercentage% of your expected life.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.tertiaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.hourglass_bottom_rounded,
                              color: theme.colorScheme.tertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'EXPECTED REMAINING TIME',
                                  maxLines: 1,
                                  style:
                                      theme.textTheme.labelLarge?.copyWith(
                                    letterSpacing: 1,
                                    color: theme.colorScheme.tertiary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          label:
                              '$remainingYears years, $remainingMonths months, $remainingDays days remaining',
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$remainingYears',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ' yrs  ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '$remainingMonths',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ' mos  ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '$remainingDays',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ' days',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _LiveRemainingDurationTicker(
                          expectedDeathDate: expectedDeathDate,
                          color: theme.colorScheme.tertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'REAL-TIME LIFE METRICS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        constraints.maxWidth < 400
                            ? 2
                            : constraints.maxWidth < 700
                            ? 3
                            : 5;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.25,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _MetricCard(
                          title: 'Total Days',
                          value: NumberFormat('#,###').format(totalDays),
                          icon: Icons.today_rounded,
                          color: theme.colorScheme.tertiary,
                        ),
                        _MetricCard(
                          title: 'Total Weeks',
                          value: (totalDays / 7).toStringAsFixed(1),
                          icon: Icons.date_range_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        _MetricCard(
                          title: 'Total Hours',
                          value: NumberFormat('#,###').format(totalHours),
                          icon: Icons.watch_later_rounded,
                          color: theme.colorScheme.secondary,
                        ),
                        _MetricCard(
                          title: 'Total Minutes',
                          value: NumberFormat('#,###').format(totalMinutes),
                          icon: Icons.timer_rounded,
                          color: theme.colorScheme.tertiary,
                        ),
                        _MetricCard(
                          title: 'Total Seconds',
                          value: NumberFormat('#,###').format(totalSeconds),
                          icon: Icons.hourglass_full_rounded,
                          color: theme.colorScheme.tertiary,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _LifeMilestonesCard(dob: widget.dob, theme: theme),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    ),
  );
}

  Future<void> _pickDate(BuildContext context, LifeProvider provider) async {
    HapticFeedback.selectionClick();
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
    HapticFeedback.selectionClick();
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reset Date of Birth'),
            content: const Text(
              'This will permanently delete your date of birth and reset the Life Tracker. Your other data will not be affected.',
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

class LifeExpectancyDialog extends StatefulWidget {
  final TextEditingController controller;
  final int initialValue;
  final ValueChanged<int> onSave;

  const LifeExpectancyDialog({
    super.key,
    required this.controller,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<LifeExpectancyDialog> createState() => _LifeExpectancyDialogState();
}

class _LifeExpectancyDialogState extends State<LifeExpectancyDialog> {
  String? _errorText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validateInput);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateInput);
    super.dispose();
  }

  void _validateInput() {
    final text = widget.controller.text.trim();
    setState(() {
      if (text.isEmpty) {
        _errorText = 'Please enter a value';
      } else {
        final value = int.tryParse(text);
        if (value == null) {
          _errorText = 'Please enter a valid number';
        } else if (value < 1) {
          _errorText = 'Must be at least 1';
        } else if (value > 120) {
          _errorText = 'Must be 120 or less';
        } else {
          _errorText = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Life Expectancy'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: 'Expected years',
              border: const OutlineInputBorder(),
              helperText: 'Average life expectancy used for progress meter',
              errorText: _errorText,
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _errorText == null && widget.controller.text.trim().isNotEmpty
                  ? () {
                      final years = int.parse(widget.controller.text.trim());
                      HapticFeedback.selectionClick();
                      widget.onSave(years);
                      Navigator.pop(context);
                    }
                  : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _LiveBadge({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$title: $value',
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(icon, color: color, size: 14),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveRemainingDurationTicker extends StatefulWidget {
  final DateTime expectedDeathDate;
  final Color color;

  const _LiveRemainingDurationTicker({
    required this.expectedDeathDate,
    required this.color,
  });

  @override
  State<_LiveRemainingDurationTicker> createState() =>
      _LiveRemainingDurationTickerState();
}

class _LiveRemainingDurationTickerState
    extends State<_LiveRemainingDurationTicker> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.expectedDeathDate.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _remaining = widget.expectedDeathDate.difference(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = _remaining.isNegative ? 0 : _remaining.inHours % 24;
    final mins = _remaining.isNegative ? 0 : _remaining.inMinutes % 60;
    final secs = _remaining.isNegative ? 0 : _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Live Ticker: ${hours}h : ${mins}m : ${secs}s remaining',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _LifeMilestonesCard extends StatelessWidget {
  final DateTime dob;
  final ThemeData theme;

  const _LifeMilestonesCard({required this.dob, required this.theme});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    DateTime nextBirthday = DateTime(now.year, dob.month, dob.day);
    if (nextBirthday.isBefore(now)) {
      nextBirthday = DateTime(now.year + 1, dob.month, dob.day);
    }
    final daysToNextBirthday = nextBirthday.difference(now).inDays;
    final turningAge = nextBirthday.year - dob.year;

    final daysLived = now.difference(dob).inDays;
    final nextMilestoneDay = ((daysLived ~/ 1000) + 1) * 1000;
    final daysToMilestone = nextMilestoneDay - daysLived;
    final nextMilestoneDate = dob.add(Duration(days: nextMilestoneDay));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upcoming Milestones',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cake_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Turning $turningAge',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          daysToNextBirthday == 0
                              ? 'Happy Birthday! 🎉'
                              : '$daysToNextBirthday day${daysToNextBirthday > 1 ? 's' : ''} away (${DateFormat('MMM d').format(nextBirthday)})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (daysToNextBirthday > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$daysToNextBirthday d',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.stars_rounded,
                      color: theme.colorScheme.tertiary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day ${NumberFormat('#,###').format(nextMilestoneDay)} of Life',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'In $daysToMilestone days on ${DateFormat('MMM d, yyyy').format(nextMilestoneDate)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$daysToMilestone d',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
