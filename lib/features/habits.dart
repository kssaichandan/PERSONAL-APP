import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../database.dart';
import '../services/notification_service.dart';
import '../utils/snackbar_utils.dart';

// =============================================================================
// Constants — Icon Map (55 icons), Categories, Color Presets
// =============================================================================

const int _defaultHabitColor = 0xFF6750A4;

IconData _getIconData(String name) {
  switch (name) {
    case 'bathtub': return Icons.bathtub_rounded;
    case 'sports_esports': return Icons.sports_esports_rounded;
    case 'fitness_center': return Icons.fitness_center_rounded;
    case 'book': return Icons.book_rounded;
    case 'water_drop': return Icons.water_drop_rounded;
    case 'bed': return Icons.bedtime_rounded;
    case 'school': return Icons.school_rounded;
    case 'star': return Icons.star_rounded;
    case 'directions_run': return Icons.directions_run_rounded;
    case 'self_improvement': return Icons.self_improvement_rounded;
    case 'spa': return Icons.spa_rounded;
    case 'pool': return Icons.pool_rounded;
    case 'hiking': return Icons.hiking_rounded;
    case 'pets': return Icons.pets_rounded;
    case 'restaurant': return Icons.restaurant_rounded;
    case 'local_drink': return Icons.local_drink_rounded;
    case 'psychology': return Icons.psychology_rounded;
    case 'lightbulb': return Icons.lightbulb_rounded;
    case 'edit_note': return Icons.edit_note_rounded;
    case 'auto_stories': return Icons.auto_stories_rounded;
    case 'headphones': return Icons.headphones_rounded;
    case 'code': return Icons.code_rounded;
    case 'weekend': return Icons.weekend_rounded;
    case 'local_florist': return Icons.local_florist_rounded;
    case 'music_note': return Icons.music_note_rounded;
    case 'coffee': return Icons.coffee_rounded;
    case 'favorite': return Icons.favorite_rounded;
    case 'payments': return Icons.payments_rounded;
    case 'shopping_cart': return Icons.shopping_cart_rounded;
    case 'savings': return Icons.savings_rounded;
    case 'account_balance': return Icons.account_balance_rounded;
    case 'receipt_long': return Icons.receipt_long_rounded;
    case 'groups': return Icons.groups_rounded;
    case 'celebration': return Icons.celebration_rounded;
    case 'diversity_3': return Icons.diversity_3_rounded;
    case 'volunteer_activism': return Icons.volunteer_activism_rounded;
    case 'emoji_emotions': return Icons.emoji_emotions_rounded;
    case 'cleaning_services': return Icons.cleaning_services_rounded;
    case 'yard': return Icons.yard_rounded;
    case 'kitchen': return Icons.kitchen_rounded;
    case 'checkroom': return Icons.checkroom_rounded;
    case 'build': return Icons.build_rounded;
    case 'eco': return Icons.eco_rounded;
    case 'bolt': return Icons.bolt_rounded;
    case 'rocket_launch': return Icons.rocket_launch_rounded;
    case 'palette': return Icons.palette_rounded;
    case 'explore': return Icons.explore_rounded;
    case 'emoji_events': return Icons.emoji_events_rounded;
    case 'schedule': return Icons.schedule_rounded;
    case 'wb_sunny': return Icons.wb_sunny_rounded;
    case 'nightlight': return Icons.nightlight_rounded;
    case 'brush': return Icons.brush_rounded;
    case 'health_and_safety': return Icons.health_and_safety_rounded;
    case 'meditation': return Icons.self_improvement_rounded;
    default: return Icons.star_rounded;
  }
}

const List<String> _allIconKeys = [
  'bathtub', 'sports_esports', 'fitness_center', 'book', 'water_drop', 'bed', 'school', 'star',
  'directions_run', 'self_improvement', 'spa', 'pool', 'hiking', 'pets', 'restaurant', 'local_drink',
  'psychology', 'lightbulb', 'edit_note', 'auto_stories', 'headphones', 'code',
  'weekend', 'local_florist', 'music_note', 'coffee', 'favorite',
  'payments', 'shopping_cart', 'savings', 'account_balance', 'receipt_long',
  'groups', 'celebration', 'diversity_3', 'volunteer_activism', 'emoji_emotions',
  'cleaning_services', 'yard', 'kitchen', 'checkroom', 'build', 'eco',
  'bolt', 'rocket_launch', 'palette', 'explore', 'emoji_events', 'schedule', 'wb_sunny', 'nightlight', 'brush', 'health_and_safety', 'meditation',
];

const Map<String, List<String>> _iconCategories = {
  'All': _allIconKeys,
  'Health': ['fitness_center', 'directions_run', 'self_improvement', 'spa', 'pool', 'hiking', 'pets', 'restaurant', 'local_drink', 'health_and_safety', 'meditation'],
  'Mind': ['book', 'school', 'psychology', 'lightbulb', 'edit_note', 'auto_stories', 'headphones', 'code'],
  'Self-Care': ['bathtub', 'water_drop', 'bed', 'weekend', 'local_florist', 'music_note', 'coffee', 'favorite', 'spa', 'nightlight'],
  'Play': ['sports_esports', 'star', 'celebration', 'emoji_emotions', 'pets', 'palette', 'explore'],
  'Finance': ['payments', 'shopping_cart', 'savings', 'account_balance', 'receipt_long'],
  'Social': ['groups', 'celebration', 'diversity_3', 'volunteer_activism', 'emoji_emotions'],
  'Home': ['cleaning_services', 'yard', 'kitchen', 'checkroom', 'build', 'eco', 'local_florist'],
  'Goals': ['bolt', 'rocket_launch', 'emoji_events', 'schedule', 'wb_sunny', 'brush', 'lightbulb'],
};

const List<int> _colorPresets = [
  0xFF6750A4,
  0xFFE53935,
  0xFFFF6D00,
  0xFFF9A825,
  0xFF43A047,
  0xFF00ACC1,
  0xFF1E88E5,
  0xFF8E24AA,
  0xFFD81B60,
  0xFF6D4C41,
  0xFF546E7A,
  0xFF00897B,
];

// =============================================================================
// Model
// =============================================================================

class Habit {
  final int? id;
  final String name;
  final String icon;
  final String? reminderTime;
  final DateTime createdAt;
  final int displayOrder;
  final int color;

  Habit({
    this.id,
    required this.name,
    required this.icon,
    this.reminderTime,
    required this.createdAt,
    this.displayOrder = 0,
    this.color = _defaultHabitColor,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'reminder_time': reminderTime,
    'created_at': createdAt.toIso8601String(),
    'display_order': displayOrder,
    'color': color,
  };

  factory Habit.fromMap(Map<String, dynamic> m) => Habit(
    id: m['id'],
    name: m['name'],
    icon: m['icon'] ?? 'star',
    reminderTime: m['reminder_time'],
    createdAt: DateTime.parse(m['created_at']),
    displayOrder: m['display_order'] ?? 0,
    color: m['color'] as int? ?? _defaultHabitColor,
  );
}

// =============================================================================
// Provider
// =============================================================================

class HabitsProvider extends ChangeNotifier {
  List<Habit> _habits = [];
  final Map<int, Set<String>> _habitLogsByHabitId = {};
  bool _loading = true;
  String? _error;
  final NotificationService _notificationService;
  final Set<int> _selectedHabits = {};
  String _searchQuery = '';

  List<Habit> get habits => _habits;
  List<Habit> get filteredHabits {
    if (_searchQuery.isEmpty) return _habits;
    final query = _searchQuery.toLowerCase();
    return _habits.where((h) => h.name.toLowerCase().contains(query)).toList();
  }

  bool get loading => _loading;
  String? get error => _error;
  Set<int> get selectedHabits => _selectedHabits;
  bool get isSelectionMode => _selectedHabits.isNotEmpty;
  String get searchQuery => _searchQuery;

  int get todayCompletedCount {
    final today = DateTime.now();
    return _habits.where((h) => isCompleted(h.id!, today)).length;
  }

  int get todayTotalCount => _habits.length;

  double get todayProgress => _habits.isEmpty ? 0.0 : todayCompletedCount / todayTotalCount;

  HabitsProvider(this._notificationService) { load(); }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

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

  Future<void> saveHabit(String name, String icon, int color, String? reminderTime, [BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      final maxOrderResult = await db.rawQuery('SELECT MAX(display_order) as max_order FROM habits');
      final maxOrder = maxOrderResult.isNotEmpty ? (maxOrderResult.first['max_order'] as int? ?? 0) : 0;

      final habit = Habit(name: name, icon: icon, color: color, reminderTime: reminderTime, createdAt: DateTime.now(), displayOrder: maxOrder + 1);
      final id = await db.insert('habits', habit.toMap()..remove('id'));
      final savedHabit = Habit(id: id, name: name, icon: icon, color: color, reminderTime: reminderTime, createdAt: habit.createdAt, displayOrder: maxOrder + 1);
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
      final updated = Habit(id: current.id, name: current.name, icon: current.icon, color: current.color, reminderTime: reminderTime, createdAt: current.createdAt);
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

  Future<void> updateHabit(int habitId, String name, String icon, int color, String? reminderTime, [BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      final current = _habits.firstWhere((h) => h.id == habitId);
      final updated = Habit(id: current.id, name: name, icon: icon, color: color, reminderTime: reminderTime, createdAt: current.createdAt, displayOrder: current.displayOrder);
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

  int completionsInWeek(int habitId, DateTime weekStart) {
    final logs = _habitLogsByHabitId[habitId] ?? {};
    int count = 0;
    final weekEnd = weekStart.add(const Duration(days: 7));
    for (final logDate in logs) {
      final parsed = DateTime.parse(logDate);
      if (parsed.isAfter(weekStart.subtract(const Duration(days: 1))) && parsed.isBefore(weekEnd)) count++;
    }
    return count;
  }
}

// =============================================================================
// Main Screen
// =============================================================================

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  Habit? _selectedHabit;
  DateTime _currentLogMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _currentWeekStart = _getWeekStart(DateTime.now());
  bool _showSearch = false;
  final _searchController = TextEditingController();

  static DateTime _getWeekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search habits...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => context.read<HabitsProvider>().setSearchQuery(v),
              )
            : Text('Habit Tracker', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _showSearch ? 'Close search' : 'Search habits',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  context.read<HabitsProvider>().setSearchQuery('');
                }
              });
            },
          ),
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Add habit',
              onPressed: () => _showAddHabitDialog(context),
            ),
        ],
      ),
      body: Consumer<HabitsProvider>(
        builder: (context, provider, _) {
          if (provider.loading) return const Center(child: CircularProgressIndicator());
          if (provider.error != null) return Center(child: Text(provider.error!, style: TextStyle(color: theme.colorScheme.error)));
          if (provider.habits.isEmpty) {
            return _buildEmptyState(context, theme, provider);
          }

          final displayHabits = provider.filteredHabits;

          if (displayHabits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No habits match "${provider.searchQuery}"', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          _selectedHabit ??= displayHabits.first;
          if (!displayHabits.any((h) => h.id == _selectedHabit!.id)) {
            _selectedHabit = displayHabits.first;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection mode bar
              if (provider.isSelectionMode)
                Container(
                  color: theme.colorScheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Text('${provider.selectedHabits.length} selected', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), visualDensity: VisualDensity.compact),
                        onPressed: provider.selectAll,
                        child: const Text('All', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), visualDensity: VisualDensity.compact),
                        onPressed: provider.clearSelection,
                        child: const Text('Clear', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), visualDensity: VisualDensity.compact, foregroundColor: theme.colorScheme.error),
                        onPressed: () => provider.deleteMultiple(provider.selectedHabits),
                        child: const Text('Delete', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              // Today's progress card
              _TodayProgressCard(provider: provider, theme: theme),

              // Habit cards horizontal scroll
              SizedBox(
                height: 120,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayHabits.length,
                  onReorderItem: (Object oldItem, int newIndex) {
                    final int oldIndex = displayHabits.indexOf(oldItem as Habit);
                    provider.reorderHabits(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final h = displayHabits[index];
                    final isSel = h.id == _selectedHabit?.id;
                    final streaks = provider.getStreaks(h.id!);
                    final currentStreak = streaks['current'] ?? 0;
                    final completedToday = provider.isCompleted(h.id!, DateTime.now());

                    return ReorderableDragStartListener(
                      key: ValueKey(h.id),
                      index: index,
                      child: GestureDetector(
                        onTap: provider.isSelectionMode
                            ? () => provider.toggleHabitSelection(h.id!)
                            : () => setState(() => _selectedHabit = h),
                        onLongPress: () => provider.toggleHabitSelection(h.id!),
                          Padding(
                          padding: EdgeInsets.only(top: provider.isSelectionMode ? 14 : 0),
                          child: Container(
                          width: 96,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSel || provider.selectedHabits.contains(h.id)
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel || provider.selectedHabits.contains(h.id)
                                  ? h.color == _defaultHabitColor ? theme.colorScheme.primary : Color(h.color)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 4),
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        _getIconData(h.icon),
                                        size: 28,
                                        color: isSel || provider.selectedHabits.contains(h.id)
                                            ? (h.color == _defaultHabitColor ? theme.colorScheme.primary : Color(h.color))
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                      if (completedToday)
                                        Positioned(
                                          right: -4,
                                          bottom: -2,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                                            ),
                                            child: const Icon(Icons.check_rounded, size: 8, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: EdgeInsets.only(left: 4, right: provider.isSelectionMode ? 8 : 4),
                                    child: Text(
                                      h.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSel || provider.selectedHabits.contains(h.id) ? FontWeight.bold : FontWeight.normal,
                                        color: isSel || provider.selectedHabits.contains(h.id) ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                    ),
                                  ),
                                  if (currentStreak > 0) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 10),
                                        Text('$currentStreak', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                ],
                              ),
                              if (provider.isSelectionMode)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: provider.selectedHabits.contains(h.id),
                                      onChanged: (_) => provider.toggleHabitSelection(h.id!),
                                      fillColor: WidgetStateProperty.resolveWith<Color>(
                                        (states) => states.contains(WidgetState.selected) ? theme.colorScheme.primary : theme.colorScheme.surfaceContainer,
                                      ),
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
                // Selected habit header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(_selectedHabit!.color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getIconData(_selectedHabit!.icon),
                          color: Color(_selectedHabit!.color),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedHabit!.name,
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
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            tooltip: 'Edit habit',
                            onPressed: () => _showEditHabitDialog(context, _selectedHabit!, provider),
                          ),
                          IconButton(
                            icon: const Icon(Icons.alarm, size: 20),
                            tooltip: 'Set reminder',
                            onPressed: () => _pickReminderTime(context, _selectedHabit!, provider),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            tooltip: 'Delete habit',
                            onPressed: () => _confirmDeleteHabit(context, _selectedHabit!, provider),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Weekly checklist with week navigation
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        tooltip: 'Previous week',
                        onPressed: () {
                          setState(() => _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7)));
                        },
                      ),
                      Text(
                        'Week of ${DateFormat('MMM d').format(_currentWeekStart)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        tooltip: 'Next week',
                        onPressed: () {
                          setState(() => _currentWeekStart = _currentWeekStart.add(const Duration(days: 7)));
                        },
                      ),
                      const Spacer(),
                      if (_currentWeekStart != _getWeekStart(DateTime.now()))
                        TextButton.icon(
                          icon: const Icon(Icons.today_rounded, size: 16),
                          label: const Text('Today', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() => _currentWeekStart = _getWeekStart(DateTime.now()));
                          },
                        ),
                    ],
                  ),
                ),
                _WeeklyChecklist(
                  habit: _selectedHabit!,
                  provider: provider,
                  weekStart: _currentWeekStart,
                ),
                const SizedBox(height: 16),

                // Monthly section header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Monthly Overview', style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
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

  Widget _buildEmptyState(BuildContext context, ThemeData theme, HabitsProvider provider) {
    final suggestions = [
      {'name': 'Read', 'icon': 'book', 'color': 0xFF1E88E5},
      {'name': 'Meditate', 'icon': 'self_improvement', 'color': 0xFF6750A4},
      {'name': 'Walk', 'icon': 'directions_run', 'color': 0xFF43A047},
      {'name': 'Drink Water', 'icon': 'water_drop', 'color': 0xFF00ACC1},
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.checklist_rtl_rounded, size: 50, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text('No habits created yet', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Start building better habits today', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddHabitDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Habit'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 32),
            Text('Quick suggestions', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: suggestions.map((s) {
                return ActionChip(
                  avatar: Icon(_getIconData(s['icon'] as String), size: 18, color: Color(s['color'] as int)),
                  label: Text(s['name'] as String, style: const TextStyle(fontSize: 13)),
                  onPressed: () {
                    provider.saveHabit(
                      s['name'] as String,
                      s['icon'] as String,
                      s['color'] as int,
                      null,
                      context,
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHabitDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    String selectedIcon = 'star';
    int selectedColor = _colorPresets[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('New Habit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Habit Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_rounded),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 20),
                const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                _HabitIconPicker(
                  selectedIcon: selectedIcon,
                  onIconSelected: (icon) => setDialogState(() => selectedIcon = icon),
                ),
                const SizedBox(height: 20),
                const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                _ColorPicker(
                  selectedColor: selectedColor,
                  onColorSelected: (color) => setDialogState(() => selectedColor = color),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create Habit'),
                    onPressed: () {
                      if (titleCtrl.text.trim().isNotEmpty) {
                        final provider = context.read<HabitsProvider>();
                        provider.saveHabit(titleCtrl.text.trim(), selectedIcon, selectedColor, null);
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => titleCtrl.dispose());
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
    int selectedColor = habit.color;
    String? selectedReminder = habit.reminderTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Edit Habit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Habit Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_rounded),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 20),
                const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                _HabitIconPicker(
                  selectedIcon: selectedIcon,
                  onIconSelected: (icon) => setDialogState(() => selectedIcon = icon),
                ),
                const SizedBox(height: 20),
                const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                _ColorPicker(
                  selectedColor: selectedColor,
                  onColorSelected: (color) => setDialogState(() => selectedColor = color),
                ),
                const SizedBox(height: 20),
                const Text('Reminder (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(selectedReminder ?? 'No reminder set'),
                          ],
                        ),
                        if (selectedReminder != null)
                          GestureDetector(
                            onTap: () => setDialogState(() => selectedReminder = null),
                            child: Icon(Icons.clear_rounded, size: 18, color: Theme.of(context).colorScheme.error),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (titleCtrl.text.trim().isNotEmpty) {
                            provider.updateHabit(habit.id!, titleCtrl.text.trim(), selectedIcon, selectedColor, selectedReminder);
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => titleCtrl.dispose());
  }
}

// =============================================================================
// Today Progress Card
// =============================================================================

class _TodayProgressCard extends StatelessWidget {
  final HabitsProvider provider;
  final ThemeData theme;

  const _TodayProgressCard({required this.provider, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (provider.habits.isEmpty) return const SizedBox.shrink();

    final completed = provider.todayCompletedCount;
    final total = provider.todayTotalCount;
    final progress = provider.todayProgress;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: progress == 1.0
                  ? const Icon(Icons.celebration_rounded, color: Colors.amber, size: 24)
                  : Icon(Icons.today_rounded, color: theme.colorScheme.primary, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed of $total habits done today',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0 ? Colors.green : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(progress * 100).toInt()}%',
            style: theme.textTheme.titleMedium?.copyWith(
              color: progress == 1.0 ? Colors.green : theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Weekly Checklist
// =============================================================================

class _WeeklyChecklist extends StatelessWidget {
  final Habit habit;
  final HabitsProvider provider;
  final DateTime weekStart;

  const _WeeklyChecklist({
    required this.habit,
    required this.provider,
    required this.weekStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final date = weekDays[index];
          final completed = provider.isCompleted(habit.id!, date);
          final isToday = date == today;
          final isFuture = date.isAfter(today);

          return Expanded(
            child: GestureDetector(
              onTap: isFuture ? null : () => provider.toggleLog(habit.id!, date),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabels[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? Color(habit.color) : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? Color(habit.color) : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AspectRatio(
                    aspectRatio: 1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color: completed
                            ? Color(habit.color)
                            : (isToday ? Color(habit.color).withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: completed
                              ? Color(habit.color)
                              : (isToday ? Color(habit.color).withValues(alpha: 0.4) : Colors.transparent),
                          width: 1.5,
                        ),
                      ),
                      child: completed
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                          : (isFuture
                              ? Icon(Icons.lock_outline_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4), size: 16)
                              : null),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// =============================================================================
// Monthly Log Calendar
// =============================================================================

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
    final habitColor = Color(habit.color);

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
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isLogged ? habitColor.withValues(alpha: 0.2) : Colors.transparent,
              border: Border.all(
                color: isLogged ? habitColor : theme.colorScheme.outlineVariant,
                width: isLogged ? 1.5 : 1,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isLogged ? FontWeight.bold : FontWeight.normal,
                color: isLogged ? habitColor : theme.colorScheme.onSurface,
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
                childAspectRatio: 1.0,
                children: cells,
              ),
              const Divider(height: 24),
              // Stats with small progress bars
              Row(
                children: [
                  Expanded(
                    child: _StatBlock(
                      icon: Icons.calendar_today_rounded,
                      title: 'Completed',
                      value: '$completedCount/$totalDays',
                      subtitle: '${(completedCount / totalDays * 100).toInt()}%',
                      color: habitColor,
                    ),
                  ),
                  Expanded(
                    child: _StatBlock(
                      icon: Icons.local_fire_department_rounded,
                      title: 'Current Streak',
                      value: '$currentStreak days',
                      color: Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _StatBlock(
                      icon: Icons.emoji_events_rounded,
                      title: 'Best Streak',
                      value: '$maxStreak days',
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              if (completedCount > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completedCount / totalDays,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(habitColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Stat Block
// =============================================================================

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final String? subtitle;

  const _StatBlock({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$title: $value',
      child: Column(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
          if (subtitle != null)
            Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// =============================================================================
// Habit Icon Picker — Horizontal Scroll (Dialog-compatible)
// =============================================================================

class _HabitIconPicker extends StatefulWidget {
  final String selectedIcon;
  final ValueChanged<String> onIconSelected;

  const _HabitIconPicker({
    required this.selectedIcon,
    required this.onIconSelected,
  });

  @override
  State<_HabitIconPicker> createState() => _HabitIconPickerState();
}

class _HabitIconPickerState extends State<_HabitIconPicker> {
  String _selectedCategory = 'All';

  List<String> get _filteredIcons => _iconCategories[_selectedCategory] ?? _allIconKeys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _iconCategories.keys.map((cat) {
              final isSelected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(cat, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  visualDensity: VisualDensity.compact,
                  labelPadding: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: _filteredIcons.isEmpty
              ? Center(
                  child: Text('No icons', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filteredIcons.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final iconName = _filteredIcons[index];
                    final isSelected = widget.selectedIcon == iconName;
                    return GestureDetector(
                      onTap: () => widget.onIconSelected(iconName),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          _getIconData(iconName),
                          size: 22,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// =============================================================================
// Color Picker
// =============================================================================

class _ColorPicker extends StatelessWidget {
  final int selectedColor;
  final ValueChanged<int> onColorSelected;

  const _ColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _colorPresets.map((color) {
        final isSelected = selectedColor == color;
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(color),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                width: isSelected ? 3 : 0,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: Color(color).withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
