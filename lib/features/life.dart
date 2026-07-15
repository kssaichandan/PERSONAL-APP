import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../database.dart';
import '../utils/snackbar_utils.dart';

class LifeProvider extends ChangeNotifier {
  DateTime? _dob;
  bool _loading = true;
  int _lifeExpectancy = 80;
  bool _biometricEnabled = false;
  bool _biometricsAvailable = true;

  DateTime? get dob => _dob;
  bool get loading => _loading;
  int get lifeExpectancy => _lifeExpectancy;
  bool get biometricEnabled => _biometricEnabled;
  bool get biometricsAvailable => _biometricsAvailable;

  LifeProvider() {
    loadDOB();
    _loadLifeExpectancy();
    _loadBiometricSetting();
    _checkBiometricsAvailable();
  }

  Future<void> _checkBiometricsAvailable() async {
    try {
      final auth = LocalAuthentication();
      _biometricsAvailable =
          await auth.canCheckBiometrics && await auth.isDeviceSupported();
    } catch (_) {
      _biometricsAvailable = false;
    }
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> _loadBiometricSetting() async {
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['biometric_enabled'],
      );
      if (maps.isNotEmpty) {
        _biometricEnabled = maps.first['value'] == 'true';
      }
    } catch (_) {}
    notifyListeners();
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
        showSuccessSnackBar(context, 'Life expectancy updated');
      }
    } catch (e) {
      debugLog('Failed to save life expectancy: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to save life expectancy');
      }
    }
  }

  Future<void> setBiometricEnabled(
    bool enabled, [
    BuildContext? context,
  ]) async {
    _biometricEnabled = enabled;
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['biometric_enabled'],
      );
      if (maps.isEmpty) {
        await db.insert('settings', {
          'key': 'biometric_enabled',
          'value': enabled.toString(),
        });
      } else {
        await db.update(
          'settings',
          {'value': enabled.toString()},
          where: 'key = ?',
          whereArgs: ['biometric_enabled'],
        );
      }
      notifyListeners();
      if (context != null && context.mounted) {
        showSuccessSnackBar(
          context,
          enabled ? 'Biometric lock enabled' : 'Biometric lock disabled',
        );
      }
    } catch (e) {
      debugLog('Failed to save biometric setting: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to save biometric setting');
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
      if (maps.isNotEmpty) _dob = DateTime.parse(maps.first['value'] as String);
    } catch (e) {
      debugLog('Failed to load DOB: $e');
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

  Future<bool> authenticate() async {
    if (!_biometricEnabled || !_biometricsAvailable) return true;
    final auth = LocalAuthentication();
    try {
      return await auth.authenticate(
        localizedReason: 'Authenticate to view Life Tracker',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
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
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading life tracker...'),
            ],
          ),
        ),
      );
    }

    if (provider.dob == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Life Tracker', style: theme.textTheme.titleLarge),
          centerTitle: true,
        ),
        body: Container(
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
                  size: 100,
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
                  'Set your date of birth to track your time elapsed and view a live-updating life progress meter.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () async {
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
                  ),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text(
                    'Enter Date of Birth',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dob = provider.dob!;
    final expectedYears = provider.lifeExpectancy;

    // Check biometric lock
    if (provider.biometricEnabled) {
      return _BiometricGuard(
        child: _LifeScreenContent(
          dob: dob,
          expectedYears: expectedYears,
          provider: provider,
        ),
      );
    }

    return _LifeScreenContent(
      dob: dob,
      expectedYears: expectedYears,
      provider: provider,
    );
  }
}

class _BiometricGuard extends StatefulWidget {
  final Widget child;
  const _BiometricGuard({required this.child});

  @override
  State<_BiometricGuard> createState() => _BiometricGuardState();
}

class _BiometricGuardState extends State<_BiometricGuard> {
  bool _authenticated = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() => _error = false);
    final provider = context.read<LifeProvider>();
    final authenticated = await provider.authenticate();
    if (mounted) {
      setState(() {
        _authenticated = authenticated;
        _error = !authenticated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_authenticated) return widget.child;

    if (_error) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Authentication Failed',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Could not verify your identity. Please try again.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Try Again'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        () => context.read<LifeProvider>().setBiometricEnabled(
                          false,
                        ),
                    child: const Text('Disable biometric lock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Authenticating...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifeScreenContent extends StatelessWidget {
  final DateTime dob;
  final int expectedYears;
  final LifeProvider provider;

  const _LifeScreenContent({
    required this.dob,
    required this.expectedYears,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dob = this.dob;
    final expectedYears = this.expectedYears;
    final provider = this.provider;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Life Journey', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed_rounded),
            tooltip: 'Life expectancy',
            onPressed: () => _showLifeExpectancyDialog(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.settings_backup_restore_rounded),
            tooltip: 'Reset date of birth',
            onPressed: () => _confirmReset(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar_rounded),
            tooltip: 'Change date of birth',
            onPressed: () => _pickDate(context, provider),
          ),
        ],
      ),
      body: StreamBuilder<DateTime>(
        stream: Stream.periodic(
          const Duration(seconds: 1),
          (_) => DateTime.now(),
        ),
        initialData: DateTime.now(),
        builder: (context, snapshot) {
          final now = snapshot.data!;
          final difference = now.difference(dob);
          int years = now.year - dob.year;
          int months = now.month - dob.month;
          int days = now.day - dob.day;
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
          final totalExpectedDays = expectedYears * 365.25;
          final lifePercentage = (totalDays / totalExpectedDays) * 100;
          final formattedPercentage = lifePercentage.toStringAsFixed(2);

          final expectedDeathDate = DateTime(
            dob.year + expectedYears,
            dob.month,
            dob.day,
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
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'TIME ELAPSED SINCE BIRTH',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            letterSpacing: 1.5,
                            color: theme.colorScheme.primary,
                          ),
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
                                    color: theme.colorScheme.onSurfaceVariant,
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
                                    color: theme.colorScheme.onSurfaceVariant,
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
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Born on ${DateFormat('MMMM d, yyyy').format(dob)}',
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
                    padding: const EdgeInsets.all(24),
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
                                color: theme.colorScheme.primary,
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
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Based on an average life expectancy of $expectedYears years.',
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
                            color:
                                lifePercentage < 50
                                    ? theme.colorScheme.primary
                                    : lifePercentage < 80
                                    ? Colors.amber.shade700
                                    : Colors.deepOrange,
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
                                  style: theme.textTheme.labelLarge?.copyWith(
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
                                    color: theme.colorScheme.onSurfaceVariant,
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
                                    color: theme.colorScheme.onSurfaceVariant,
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
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                    final crossAxisCount = constraints.maxWidth < 400 ? 1 : 3;
                    final childAspectRatio = crossAxisCount == 1 ? 3.2 : 1.35;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: childAspectRatio,
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
                          color: theme.colorScheme.error,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
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
      builder:
          (ctx) => AlertDialog(
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
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
    controller.dispose();
  }

  Future<void> _confirmReset(
    BuildContext context,
    LifeProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reset DOB'),
            content: const Text(
              'Are you sure you want to delete your Date of Birth? This will reset the Life Tracker.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Reset',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      await provider.resetDOB(context);
    }
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
                        fontSize: 10,
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
