import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database.dart';

class LifeProvider extends ChangeNotifier {
  DateTime? _dob;
  bool _loading = true;

  DateTime? get dob => _dob;
  bool get loading => _loading;

  LifeProvider() { loadDOB(); }

  Future<void> loadDOB() async {
    _loading = true;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query('settings', where: 'key = ?', whereArgs: ['dob']);
      if (maps.isNotEmpty) {
        _dob = DateTime.parse(maps.first['value'] as String);
      }
    } catch (e) {
      debugPrint('loadDOB failed: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> saveDOB(DateTime date) async {
    try {
      final db = await AppDatabase.instance.database;
      final val = DateFormat('yyyy-MM-dd').format(date);
      
      final maps = await db.query('settings', where: 'key = ?', whereArgs: ['dob']);
      if (maps.isEmpty) {
        await db.insert('settings', {'key': 'dob', 'value': val});
      } else {
        await db.update('settings', {'value': val}, where: 'key = ?', whereArgs: ['dob']);
      }
      _dob = DateTime(date.year, date.month, date.day);
      notifyListeners();
    } catch (e) {
      debugPrint('saveDOB failed: $e');
    }
  }

  Future<void> resetDOB() async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('settings', where: 'key = ?', whereArgs: ['dob']);
      _dob = null;
      notifyListeners();
    } catch (e) {
      debugPrint('resetDOB failed: $e');
    }
  }
}

class LifeScreen extends StatefulWidget {
  const LifeScreen({super.key});

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update every 100 milliseconds for smooth millisecond ticking
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<LifeProvider>();

    if (provider.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (provider.dob == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Life Tracker', style: TextStyle(fontWeight: FontWeight.bold))),
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
                Icon(Icons.hourglass_empty_rounded, size: 100, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'How many days have you been alive?',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Set your date of birth to track your time elapsed and view a live-updating life progress meter.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () => _pickDate(context, provider),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Enter Date of Birth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculations
    final dob = provider.dob!;
    final now = DateTime.now();
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
    final totalMillis = difference.inMilliseconds;

    // Based on average life expectancy of 80 years
    const expectedYears = 80;
    const totalExpectedDays = expectedYears * 365.25;
    final lifePercentage = (totalDays / totalExpectedDays) * 100;
    final formattedPercentage = lifePercentage.toStringAsFixed(7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Journey', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_backup_restore_rounded),
            tooltip: 'Reset DOB',
            onPressed: () => _confirmReset(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar_rounded),
            tooltip: 'Change DOB',
            onPressed: () => _pickDate(context, provider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time Elapsed Title
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text('TIME ELAPSED SINCE BIRTH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: theme.colorScheme.primary)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$years', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                        const Text(' yrs  ', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        Text('$months', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                        const Text(' mos  ', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        Text('$days', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                        const Text(' days', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Born on ${DateFormat('MMMM d, yyyy').format(dob)}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Life Meter
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Life Progress Meter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('$formattedPercentage%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (lifePercentage / 100).clamp(0.0, 1.0),
                        minHeight: 14,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Based on an average life expectancy of $expectedYears years.',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Exact Realtime Metrics Cards Grid
            Text('REAL-TIME LIFE METRICS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _MetricCard(
                  title: 'Total Days',
                  value: NumberFormat('#,###').format(totalDays),
                  icon: Icons.today_rounded,
                  color: Colors.teal,
                ),
                _MetricCard(
                  title: 'Total Hours',
                  value: NumberFormat('#,###').format(totalHours),
                  icon: Icons.watch_later_rounded,
                  color: Colors.blue,
                ),
                _MetricCard(
                  title: 'Total Minutes',
                  value: NumberFormat('#,###').format(totalMinutes),
                  icon: Icons.timer_rounded,
                  color: Colors.indigo,
                ),
                _MetricCard(
                  title: 'Total Seconds',
                  value: NumberFormat('#,###').format(totalSeconds),
                  icon: Icons.hourglass_full_rounded,
                  color: Colors.amber.shade800,
                ),
              ],
            ),

            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Ticking milliseconds:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    Text(
                      NumberFormat('#,###').format(totalMillis),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.purple),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickDate(BuildContext context, LifeProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.dob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await provider.saveDOB(picked);
    }
  }

  void _confirmReset(BuildContext context, LifeProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset DOB'),
        content: const Text('Are you sure you want to delete your Date of Birth? This will reset the Life Tracker.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.resetDOB();
              Navigator.pop(ctx);
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Icon(icon, color: color, size: 18),
              ],
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            )
          ],
        ),
      ),
    );
  }
}
