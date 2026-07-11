import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../database.dart';
import '../services/notification_service.dart';
import '../utils/snackbar_utils.dart';

class Habit {
  final int? id;
  final String name;
  final String icon;
  final String? reminderTime;
  final DateTime createdAt;
  final int displayOrder;

  Habit({this.id, required this.name, required this.icon, this.reminderTime, required this.createdAt, this.displayOrder = 0});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'reminder_time': reminderTime,
    'created_at': createdAt.toIso8601String(),
    'display_order': displayOrder,
  };

  factory Habit.fromMap(Map<String, dynamic> m) => Habit(
    id: m['id'],
    name: m['name'],
    icon: m['icon'] ?? 'star',
    reminderTime: m['reminder_time'],
    createdAt: DateTime.parse(m['created_at']),
    displayOrder: m['display_order'] ?? 0,
  );
}

class HabitsProvider extends ChangeNotifier {
  List<Habit> _habits = [];
  final Map<int, Set<String>> _habitLogsByHabitId = {};
  bool _loading = true;
  String? _error;
  final NotificationService _notificationService;
  final Set<int> _selectedHabits = {};

  List<Habit> get habits => _habits;
  bool get loading => _loading;
  String? get error => _error;
  Set<int> get selectedHabits => _selectedHabits;
  bool get isSelectionMode => _selectedHabits.isNotEmpty;

  HabitsProvider(this._notificationService) { load(); }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      final habitMaps = await db.query('habits', orderBy: 'display_order ASC, created_at ASC');
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

  Future<void> toggleLog(int habitId, DateTime date, [BuildContext? context]) async {
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
      debugLog('Failed to toggle habit log: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to update habit');
      }
    }
  }

  Future<void> saveHabit(String name, String icon, String? reminderTime, [BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      // Get max display_order
      final maxOrderResult = await db.rawQuery('SELECT MAX(display_order) as max_order FROM habits');
      final maxOrder = maxOrderResult.isNotEmpty ? (maxOrderResult.first['max_order'] as int? ?? 0) : 0;
      
      final habit = Habit(name: name, icon: icon, reminderTime: reminderTime, createdAt: DateTime.now(), displayOrder: maxOrder + 1);
      final id = await db.insert('habits', habit.toMap()..remove('id'));
      final savedHabit = Habit(id: id, name: name, icon: icon, reminderTime: reminderTime, createdAt: habit.createdAt, displayOrder: maxOrder + 1);
      if (reminderTime != null) _scheduleHabitNotification(savedHabit);
      if (context != null && context.mounted) {
        showSuccessSnackBar(context, 'Habit created');
      }
    } catch (e) {
      debugLog('Failed to save habit: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to create habit');
      }
    }
    await load();
  }

  Future<void> deleteHabit(int id, [BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('habits', where: 'id = ?', whereArgs: [id]);
      await _notificationService.cancel(1000 + id);
      if (context != null && context.mounted) {
        showSuccessSnackBar(context, 'Habit deleted');
      }
    } catch (e) {
      debugLog('Failed to delete habit: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to delete habit');
      }
    }
    await load();
  }

  Future<void> updateReminder(int habitId, String? reminderTime, [BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      final current = _habits.firstWhere((h) => h.id == habitId);
      final updated = Habit(id: current.id, name: current.name, icon: current.icon, reminderTime: reminderTime, createdAt: current.createdAt);
      await db.update('habits', updated.toMap(), where: 'id = ?', whereArgs: [habitId]);
      await _notificationService.cancel(1000 + habitId);
      if (reminderTime != null) _scheduleHabitNotification(updated);
      if (context != null && context.mounted) {
        showSuccessSnackBar(context, 'Reminder updated');
      }
    } catch (e) {
      debugLog('Failed to update reminder: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to update reminder');
      }
    }
    await load();
  }

  Future<void> updateHabit(int habitId, String name, String icon, String? reminderTime, [BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      final current = _habits.firstWhere((h) => h.id == habitId);
      final updated = Habit(id: current.id, name: name, icon: icon, reminderTime: reminderTime, createdAt: current.createdAt, displayOrder: current.displayOrder);
      await db.update('habits', updated.toMap(), where: 'id = ?', whereArgs: [habitId]);
      await _notificationService.cancel(1000 + habitId);
      if (reminderTime != null) _scheduleHabitNotification(updated);
      if (context != null && context.mounted) {
        showSuccessSnackBar(context, 'Habit updated');
      }
    } catch (e) {
      debugLog('Failed to update habit: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to update habit');
      }
    }
    await load();
  }

  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex--;
    final habit = _habits.removeAt(oldIndex);
    _habits.insert(newIndex, habit);
    
    // Update display_order in database
    try {
      final db = await AppDatabase.instance.database;
      for (int i = 0; i < _habits.length; i++) {
        final h = _habits[i];
        if (h.displayOrder != i) {
          await db.update('habits', {'display_order': i}, where: 'id = ?', whereArgs: [h.id]);
        }
      }
    } catch (e) {
      debugLog('Failed to update habit order: $e');
    }
    
    notifyListeners();
  }

  // Selection mode methods
  void toggleHabitSelection(int habitId) {
    if (_selectedHabits.contains(habitId)) {
      _selectedHabits.remove(habitId);
    } else {
      _selectedHabits.add(habitId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedHabits.clear();
    notifyListeners();
  }

  void selectAll() {
    _selectedHabits.addAll(_habits.map((h) => h.id!).toSet());
    notifyListeners();
  }

  Future<void> deleteMultiple(Set<int> ids, [BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      for (final id in ids) {
        await db.delete('habits', where: 'id = ?', whereArgs: [id]);
        await _notificationService.cancel(1000 + id);
      }
      _selectedHabits.clear();
      if (context != null && context.mounted) {
        showSuccessSnackBar(context, '${ids.length} habits deleted');
      }
    } catch (e) {
      debugLog('Failed to delete habits: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to delete habits');
      }
      return;
    }
    await load();
  }

  void _scheduleHabitNotification(Habit habit) {
    if (habit.id == null || habit.reminderTime == null) return;
    final parts = habit.reminderTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    unawaited(_notificationService.zonedSchedule(
      1000 + habit.id!,
      'Habit Reminder: ${habit.name}',
      'Time to complete your habit! Tap to log it.',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails('habits', 'Habit Reminders', importance: Importance.high, priority: Priority.high),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    ).catchError((_) {}));
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 1));
    return scheduledDate;
  }

  Map<String, int> getStreaks(int habitId) {
    final dates = _habitLogsByHabitId[habitId] ?? {};
    if (dates.isEmpty) return {'current': 0, 'max': 0};
    final sorted = dates.map((d) => DateTime.parse(d)).toList()..sort();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final yesterday = today.subtract(const Duration(days: 1));
    int maxStreak = 0;
    int temp = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
        temp++;
      } else {
        if (temp > maxStreak) maxStreak = temp;
        temp = 1;
      }
    }
    if (temp > maxStreak) maxStreak = temp;
    final last = sorted.last;
    int currentStreak = 0;
    if (last == today || last == yesterday) {
      currentStreak = 1;
      for (int i = sorted.length - 2; i >= 0; i--) {
        if (sorted[i + 1].difference(sorted[i]).inDays == 1) {
          currentStreak++;
        } else {
          break;
        }
      }
    }
    return {'current': currentStreak, 'max': maxStreak};
  }

  int completionsInMonth(int habitId, DateTime month) {
    final logs = _habitLogsByHabitId[habitId] ?? {};
    int count = 0;
    for (final logDate in logs) {
      final parsed = DateTime.parse(logDate);
      if (parsed.year == month.year && parsed.month == month.month) count++;
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
        title: Text('Habit Tracker', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Add habit',
            onPressed: () => _showAddHabitDialog(context),
          )
        ],
      ),
      body: Consumer<HabitsProvider>(
        builder: (context, provider, _) {
          if (provider.loading) return const Center(child: CircularProgressIndicator());
          if (provider.error != null) return Center(child: Text(provider.error!, style: TextStyle(color: theme.colorScheme.error)));
          if (provider.habits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_rtl_rounded, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No habits created yet', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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

          _selectedHabit ??= provider.habits.first;
          if (!provider.habits.any((h) => h.id == _selectedHabit!.id)) {
            _selectedHabit = provider.habits.first;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.isSelectionMode)
                Container(
                  color: theme.colorScheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('${provider.selectedHabits.length} selected', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.select_all_rounded),
                        label: const Text('Select All'),
                        onPressed: () {
                          for (final h in provider.habits) {
                            provider.selectedHabits.add(h.id!);
                          }
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_rounded),
                        label: const Text('Clear'),
                        onPressed: provider.clearSelection,
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.delete_rounded, color: theme.colorScheme.error),
                        label: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                        onPressed: () async {
                          await provider.deleteMultiple(provider.selectedHabits, context);
                        },
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: MediaQuery.of(context).orientation == Orientation.landscape ? 90 : 110,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: provider.habits.length,
                  onReorderItem: (Object oldItem, int newIndex) {
                    final int oldIndex = provider.habits.indexOf(oldItem as Habit);
                    provider.reorderHabits(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final h = provider.habits[index];
                    final isSel = h.id == _selectedHabit?.id;
                    final streaks = provider.getStreaks(h.id!);
                    final currentStreak = streaks['current'] ?? 0;
                    return ReorderableDragStartListener(
                      key: ValueKey(h.id),
                      index: index,
                      child: GestureDetector(
                        onTap: provider.isSelectionMode
                            ? () => provider.toggleHabitSelection(h.id!)
                            : () => setState(() => _selectedHabit = h),
                        onLongPress: () => provider.toggleHabitSelection(h.id!),
                        child: Container(
                          width: 90,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSel || provider.selectedHabits.contains(h.id)
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: isSel || provider.selectedHabits.contains(h.id)
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                width: 2),
                          ),
                          child: Stack(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.drag_indicator_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                      const SizedBox(width: 4),
                                    ],
                                  ),
                                  Icon(_getIconData(h.icon), color: isSel || provider.selectedHabits.contains(h.id) ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(height: 4),
                                  Text(
                                    h.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSel || provider.selectedHabits.contains(h.id) ? FontWeight.bold : FontWeight.normal,
                                      color: isSel || provider.selectedHabits.contains(h.id) ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (currentStreak > 0) ...[
                                    const SizedBox(height: 2),
                                    Semantics(
                                      label: 'Current streak: $currentStreak days',
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.local_fire_department, color: Colors.orange, size: 12),
                                          Text('$currentStreak', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                        ],
                                      ),
                                    )
                                  ]
                                ],
                              ),
                              if (provider.isSelectionMode)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Checkbox(
                                    value: provider.selectedHabits.contains(h.id),
                                    onChanged: (_) => provider.toggleHabitSelection(h.id!),
                                    fillColor: WidgetStateProperty.resolveWith<Color>(
                                      (states) => states.contains(WidgetState.selected) ? theme.colorScheme.primary : theme.colorScheme.surfaceContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                    },
                ),
              ),
              const Divider(height: 1),
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
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              _selectedHabit!.reminderTime == null
                                ? 'No reminder set'
                                : 'Daily reminder at ${_selectedHabit!.reminderTime}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded),
                            tooltip: 'Edit habit',
                            onPressed: () => _showEditHabitDialog(context, _selectedHabit!, provider),
                          ),
                          IconButton(
                            icon: const Icon(Icons.alarm),
                            tooltip: 'Set reminder',
                            onPressed: () => _pickReminderTime(context, _selectedHabit!, provider),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: 'Delete habit',
                            onPressed: () => _confirmDeleteHabit(context, _selectedHabit!, provider),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _WeeklyChecklist(habit: _selectedHabit!, provider: provider),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Monthly Overview', style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: _MonthlyLogCalendar(
                      habit: _selectedHabit!,
                      provider: provider,
                      currentMonth: _currentLogMonth,
                      onMonthChanged: (newMonth) {
                        setState(() => _currentLogMonth = newMonth);
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
                        border: Border.all(color: isSel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
                      ),
                      child: Icon(_getIconData(iconName), color: isSel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
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
                  provider.saveHabit(titleCtrl.text.trim(), selectedIcon, null, ctx);
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
    if (picked != null && context.mounted) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await provider.updateReminder(habit.id!, formatted, context);
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
              provider.deleteHabit(habit.id!, context);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditHabitDialog(BuildContext context, Habit habit, HabitsProvider provider) {
    final titleCtrl = TextEditingController(text: habit.name);
    String selectedIcon = habit.icon;
    String? selectedReminder = habit.reminderTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Habit'),
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
                        border: Border.all(color: isSel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
                      ),
                      child: Icon(_getIconData(iconName), color: isSel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Reminder Time (optional)'),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  TimeOfDay? initial;
                  if (selectedReminder != null) {
                    final parts = selectedReminder!.split(':');
                    initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                  }
                  final picked = await showTimePicker(context: context, initialTime: initial ?? TimeOfDay.now());
                  if (picked != null) {
                    setDialogState(() => selectedReminder = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(selectedReminder ?? 'No reminder set'),
                      const Icon(Icons.access_time_rounded),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  provider.updateHabit(habit.id!, titleCtrl.text.trim(), selectedIcon, selectedReminder, context);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
    final todayWeekday = now.weekday;
    final monday = now.subtract(Duration(days: todayWeekday - 1));
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
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
                style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.day}',
                style: TextStyle(fontSize: 10, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: isFuture ? null : () {
                  provider.toggleLog(habit.id!, date);
                  if (!completed) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Completed "${habit.name}"!'),
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
                        : (isToday ? theme.colorScheme.primary.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: completed ? theme.colorScheme.primary : (isToday ? theme.colorScheme.primary : Colors.transparent),
                      width: 1.5,
                    ),
                  ),
                  child: completed
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : (isFuture
                          ? Icon(Icons.lock_outline_rounded, color: theme.colorScheme.onSurfaceVariant, size: 14)
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
    final startWeekday = firstDay.weekday;
    final completedCount = provider.completionsInMonth(habit.id!, currentMonth);
    final streakStats = provider.getStreaks(habit.id!);
    final currentStreak = streakStats['current'] ?? 0;
    final maxStreak = streakStats['max'] ?? 0;
    final cells = <Widget>[];
    for (int i = 1; i < startWeekday; i++) { cells.add(const SizedBox()); }
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
              color: isLogged ? theme.colorScheme.primary.withValues(alpha: 0.2) : Colors.transparent,
              border: Border.all(color: isLogged ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: isLogged ? 1.5 : 1),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                    onPressed: () => onMonthChanged(DateTime(currentMonth.year, currentMonth.month - 1)),
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(currentMonth),
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                    onPressed: () => onMonthChanged(DateTime(currentMonth.year, currentMonth.month + 1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((d) => Expanded(child: Center(child: Text(d, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)))))
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: cells,
              ),
              const Divider(height: 24),
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
  const _StatBlock({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$title: $value',
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
