import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../database.dart';
import '../notifications.dart';

class Habit {
  final int? id;
  final String name;
  final String icon;
  final String? reminderTime; // e.g. "08:00"
  final DateTime createdAt;

  Habit({this.id, required this.name, required this.icon, this.reminderTime, required this.createdAt});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'reminder_time': reminderTime,
    'created_at': createdAt.toIso8601String(),
  };

  factory Habit.fromMap(Map<String, dynamic> m) => Habit(
    id: m['id'],
    name: m['name'],
    icon: m['icon'] ?? 'star',
    reminderTime: m['reminder_time'],
    createdAt: DateTime.parse(m['created_at']),
  );

  Habit copyWith({String? name, String? icon, String? reminderTime}) => Habit(
    id: id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    reminderTime: reminderTime ?? this.reminderTime,
    createdAt: createdAt,
  );
}

class HabitsProvider extends ChangeNotifier {
  List<Habit> _habits = [];
  Map<int, Set<String>> _habitLogsByHabitId = {}; // habitId -> Set of "yyyy-MM-dd"
  bool _loading = true;
  String? _error;

  List<Habit> get habits => _habits;
  bool get loading => _loading;
  String? get error => _error;

  HabitsProvider() { load(); }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      
      final habitMaps = await db.query('habits', orderBy: 'created_at ASC');
      _habits = habitMaps.map((m) => Habit.fromMap(m)).toList();

      final logMaps = await db.query('habit_logs');
      _habitLogsByHabitId.clear();
      for (final log in logMaps) {
        final hId = log['habit_id'] as int;
        final dateStr = log['date'] as String;
        _habitLogsByHabitId.putIfAbsent(hId, () => {}).add(dateStr);
      }
    } catch (e) {
      _error = 'Failed to load habits';
    }
    _loading = false;
    notifyListeners();
  }

  bool isCompleted(int habitId, DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return _habitLogsByHabitId[habitId]?.contains(dateStr) ?? false;
  }

  Future<void> toggleLog(int habitId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final db = await AppDatabase.instance.database;
      final logs = _habitLogsByHabitId[habitId] ?? {};
      
      if (logs.contains(dateStr)) {
        await db.delete('habit_logs', where: 'habit_id = ? AND date = ?', whereArgs: [habitId, dateStr]);
        _habitLogsByHabitId[habitId]?.remove(dateStr);
      } else {
        await db.insert('habit_logs', {'habit_id': habitId, 'date': dateStr});
        _habitLogsByHabitId.putIfAbsent(habitId, () => {}).add(dateStr);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('toggleLog failed: $e');
    }
  }

  Future<void> saveHabit(String name, String icon, String? reminderTime) async {
    try {
      final db = await AppDatabase.instance.database;
      final habit = Habit(name: name, icon: icon, reminderTime: reminderTime, createdAt: DateTime.now());
      final id = await db.insert('habits', habit.toMap()..remove('id'));
      
      final savedHabit = Habit(id: id, name: name, icon: icon, reminderTime: reminderTime, createdAt: habit.createdAt);
      if (reminderTime != null) {
        _scheduleHabitNotification(savedHabit);
      }
    } catch (e) {
      debugPrint('saveHabit failed: $e');
    }
    await load();
  }

  Future<void> deleteHabit(int id) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('habits', where: 'id = ?', whereArgs: [id]);
      await notifications.cancel(1000 + id);
    } catch (e) {
      debugPrint('deleteHabit failed: $e');
    }
    await load();
  }

  Future<void> updateReminder(int habitId, String? reminderTime) async {
    try {
      final db = await AppDatabase.instance.database;
      final current = _habits.firstWhere((h) => h.id == habitId);
      final updated = current.copyWith(reminderTime: reminderTime);
      await db.update('habits', updated.toMap(), where: 'id = ?', whereArgs: [habitId]);
      
      await notifications.cancel(1000 + habitId);
      if (reminderTime != null) {
        _scheduleHabitNotification(updated);
      }
    } catch (e) {
      debugPrint('updateReminder failed: $e');
    }
    await load();
  }

  void _scheduleHabitNotification(Habit habit) {
    if (habit.id == null || habit.reminderTime == null) return;
    final parts = habit.reminderTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    unawaited(notifications.zonedSchedule(
      1000 + habit.id!,
      'Habit Reminder: ${habit.name}',
      'Time to complete your habit! Tap to log it.',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habits',
          'Habit Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    ).catchError((e) {
      debugPrint('scheduleHabitNotification failed: $e');
    }));
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Map<String, int> getStreaks(int habitId) {
    final dates = _habitLogsByHabitId[habitId] ?? {};
    if (dates.isEmpty) return {'current': 0, 'max': 0};

    final sortedDates = dates.map((d) => DateTime.parse(d)).toList()..sort();
    
    int maxStreak = 0;
    int currentStreak = 0;
    int tempStreak = 0;

    DateTime? prev;
    for (final date in sortedDates) {
      if (prev == null) {
        tempStreak = 1;
      } else {
        final diff = date.difference(prev).inDays;
        if (diff == 1) {
          tempStreak++;
        } else if (diff > 1) {
          if (tempStreak > maxStreak) maxStreak = tempStreak;
          tempStreak = 1;
        }
      }
      prev = date;
    }
    if (tempStreak > maxStreak) maxStreak = tempStreak;

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final yesterday = today.subtract(const Duration(days: 1));
    final formattedToday = DateFormat('yyyy-MM-dd').format(today);
    final formattedYesterday = DateFormat('yyyy-MM-dd').format(yesterday);

    if (dates.contains(formattedToday)) {
      int streak = 0;
      DateTime d = today;
      while (dates.contains(DateFormat('yyyy-MM-dd').format(d))) {
        streak++;
        d = d.subtract(const Duration(days: 1));
      }
      currentStreak = streak;
    } else if (dates.contains(formattedYesterday)) {
      int streak = 0;
      DateTime d = yesterday;
      while (dates.contains(DateFormat('yyyy-MM-dd').format(d))) {
        streak++;
        d = d.subtract(const Duration(days: 1));
      }
      currentStreak = streak;
    } else {
      currentStreak = 0;
    }

    return {'current': currentStreak, 'max': maxStreak};
  }

  int completionsInMonth(int habitId, DateTime month) {
    final logs = _habitLogsByHabitId[habitId] ?? {};
    int count = 0;
    for (final logDate in logs) {
      final parsed = DateTime.parse(logDate);
      if (parsed.year == month.year && parsed.month == month.month) {
        count++;
      }
    }
    return count;
  }
}

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  Habit? _selectedHabit;
  DateTime _currentLogMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _showAddHabitDialog(context),
          )
        ],
      ),
      body: Consumer<HabitsProvider>(
        builder: (context, provider, _) {
          if (provider.loading) return const Center(child: CircularProgressIndicator());
          if (provider.error != null) return Center(child: Text(provider.error!));
          if (provider.habits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_rtl_rounded, size: 80, color: theme.colorScheme.primary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text('No habits created yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddHabitDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Custom Habit'),
                  )
                ],
              ),
            );
          }

          // If no habit is selected yet, select the first one
          _selectedHabit ??= provider.habits.first;

          // Double check if selected habit still exists
          if (!provider.habits.any((h) => h.id == _selectedHabit!.id)) {
            _selectedHabit = provider.habits.first;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Habits Horizontal Selection
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: provider.habits.length,
                  itemBuilder: (context, index) {
                    final h = provider.habits[index];
                    final isSel = h.id == _selectedHabit?.id;
                    final streaks = provider.getStreaks(h.id!);
                    final currentStreak = streaks['current'] ?? 0;
                    
                    return GestureDetector(
                      onTap: () => setState(() => _selectedHabit = h),
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSel ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel ? theme.colorScheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_getIconData(h.icon), color: isSel ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 4),
                            Text(
                              h.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (currentStreak > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 12),
                                  Text('$currentStreak', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                ],
                              )
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Weekly Checklist Widget for Selected Habit
              if (_selectedHabit != null) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Log Habit: ${_selectedHabit!.name}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _selectedHabit!.reminderTime == null 
                                ? 'No reminder alarm set' 
                                : 'Daily reminder at ${_selectedHabit!.reminderTime}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.alarm),
                            onPressed: () => _pickReminderTime(context, _selectedHabit!, provider),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => _confirmDeleteHabit(context, _selectedHabit!, provider),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _WeeklyChecklist(habit: _selectedHabit!, provider: provider),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Monthly Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: _MonthlyLogCalendar(
                      habit: _selectedHabit!,
                      provider: provider,
                      currentMonth: _currentLogMonth,
                      onMonthChanged: (newMonth) {
                        setState(() {
                          _currentLogMonth = newMonth;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'bathtub': return Icons.bathtub_rounded;
      case 'sports_esports': return Icons.sports_esports_rounded;
      case 'fitness_center': return Icons.fitness_center_rounded;
      case 'book': return Icons.book_rounded;
      case 'water_drop': return Icons.water_drop_rounded;
      case 'bed': return Icons.bedtime_rounded;
      case 'school': return Icons.school_rounded;
      default: return Icons.star_rounded;
    }
  }

  void _showAddHabitDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    String selectedIcon = 'star';
    final provider = context.read<HabitsProvider>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Custom Habit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Habit Name', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Select Icon'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ['bathtub', 'sports_esports', 'fitness_center', 'book', 'water_drop', 'bed', 'school', 'star'].map((iconName) {
                  final isSel = selectedIcon == iconName;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = iconName),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSel ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey.shade400),
                      ),
                      child: Icon(_getIconData(iconName), color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey.shade600),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  provider.saveHabit(titleCtrl.text.trim(), selectedIcon, null);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _pickReminderTime(BuildContext context, Habit habit, HabitsProvider provider) async {
    final now = TimeOfDay.now();
    TimeOfDay? initial;
    if (habit.reminderTime != null) {
      final parts = habit.reminderTime!.split(':');
      initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    final picked = await showTimePicker(context: context, initialTime: initial ?? now);
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await provider.updateReminder(habit.id!, formatted);
    }
  }

  void _confirmDeleteHabit(BuildContext context, Habit habit, HabitsProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text('Are you sure you want to delete "${habit.name}" and all of its progress logs?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.deleteHabit(habit.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChecklist extends StatelessWidget {
  final Habit habit;
  final HabitsProvider provider;

  const _WeeklyChecklist({required this.habit, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1 = Mon ... 7 = Sun
    
    // Compute the start (Monday) of this week
    final monday = now.subtract(Duration(days: todayWeekday - 1));

    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final date = weekDays[index];
          final completed = provider.isCompleted(habit.id!, date);
          final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
          final isFuture = date.isAfter(now);

          return Column(
            children: [
              Text(
                dayNames[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? theme.colorScheme.primary : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? theme.colorScheme.primary : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: isFuture 
                  ? null 
                  : () {
                      provider.toggleLog(habit.id!, date);
                      if (!completed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Completed "${habit.name}"! 🎉'),
                            duration: const Duration(milliseconds: 600),
                            behavior: SnackBarBehavior.floating,
                          )
                        );
                      }
                    },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: completed
                        ? theme.colorScheme.primary
                        : (isToday ? theme.colorScheme.primary.withOpacity(0.08) : Colors.grey.shade200),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: completed 
                          ? theme.colorScheme.primary 
                          : (isToday ? theme.colorScheme.primary : Colors.transparent),
                      width: 1.5,
                    ),
                  ),
                  child: completed
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : (isFuture 
                          ? Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400, size: 14)
                          : null),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _MonthlyLogCalendar extends StatelessWidget {
  final Habit habit;
  final HabitsProvider provider;
  final DateTime currentMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const _MonthlyLogCalendar({
    required this.habit,
    required this.provider,
    required this.currentMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final totalDays = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday; // 1 = Mon ... 7 = Sun
    
    final completedCount = provider.completionsInMonth(habit.id!, currentMonth);
    final streakStats = provider.getStreaks(habit.id!);
    final currentStreak = streakStats['current'] ?? 0;
    final maxStreak = streakStats['max'] ?? 0;

    final cells = <Widget>[];
    for (int i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      final isLogged = provider.isCompleted(habit.id!, date);
      
      cells.add(
        Center(
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isLogged 
                  ? theme.colorScheme.primary.withOpacity(0.2) 
                  : Colors.transparent,
              border: Border.all(
                color: isLogged ? theme.colorScheme.primary : Colors.grey.shade300,
                width: isLogged ? 1.5 : 1,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isLogged ? FontWeight.bold : FontWeight.normal,
                color: isLogged ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Month Navigator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      onMonthChanged(DateTime(currentMonth.year, currentMonth.month - 1));
                    },
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(currentMonth),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      onMonthChanged(DateTime(currentMonth.year, currentMonth.month + 1));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Calendar Grid Header
              Row(
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)))))
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Calendar Days Grid
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: cells,
              ),
              const Divider(height: 24),

              // Statistics Panels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatBlock(
                    icon: Icons.calendar_today_rounded,
                    title: 'Completed',
                    value: '$completedCount times',
                    color: theme.colorScheme.primary,
                  ),
                  _StatBlock(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Current Streak',
                    value: '$currentStreak days',
                    color: Colors.orange,
                  ),
                  _StatBlock(
                    icon: Icons.emoji_events_rounded,
                    title: 'Max Streak',
                    value: '$maxStreak days',
                    color: Colors.amber,
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

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatBlock({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
