import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database.dart';
import '../utils/snackbar_utils.dart';
import 'settings_provider.dart';
import '../services/notification_service.dart';

const _calendarCategories = ['General', 'Work', 'Personal', 'Urgent'];
const _recurrenceOptions = ['none', 'daily', 'weekly', 'monthly'];
const _recurrenceLabels = ['None', 'Daily', 'Weekly', 'Monthly'];
const int _maxTitleLength = 80;
const int _maxNotesLength = 300;

enum CalendarViewMode { month, week, day, agenda }

Color _categoryColor(String category, ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  return switch (category) {
    'Work' => isDark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2),
    'Personal' => isDark ? const Color(0xFF81C784) : const Color(0xFF388E3C),
    'Urgent' => isDark ? const Color(0xFFE57373) : const Color(0xFFD32F2F),
    _ => theme.colorScheme.primary,
  };
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'Work' => Icons.work_rounded,
    'Personal' => Icons.person_rounded,
    'Urgent' => Icons.warning_amber_rounded,
    _ => Icons.event_note_rounded,
  };
}

class CalendarEvent {
  final int? id;
  final String title;
  final DateTime date;
  final String? time;
  final String notes;
  final String category;
  final String recurrence;
  final DateTime? recurrenceEnd;

  CalendarEvent({
    this.id,
    required this.title,
    required this.date,
    this.time,
    this.notes = '',
    this.category = 'General',
    this.recurrence = 'none',
    this.recurrenceEnd,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'date': DateFormat('yyyy-MM-dd').format(date),
    'time': time,
    'notes': notes,
    'category': category,
    'recurrence': recurrence,
    'recurrence_end':
        recurrenceEnd != null
            ? DateFormat('yyyy-MM-dd').format(recurrenceEnd!)
            : null,
  };

  factory CalendarEvent.fromMap(Map<String, dynamic> m) => CalendarEvent(
    id: m['id'],
    title: m['title'],
    date: DateFormat('yyyy-MM-dd').parse(m['date']),
    time: m['time'],
    notes: m['notes'] ?? '',
    category: m['category'] ?? 'General',
    recurrence: m['recurrence'] ?? 'none',
    recurrenceEnd:
        m['recurrence_end'] != null
            ? DateFormat('yyyy-MM-dd').parse(m['recurrence_end'])
            : null,
  );

  CalendarEvent copyWith({
    int? id,
    String? title,
    DateTime? date,
    String? time,
    String? notes,
    String? category,
    String? recurrence,
    DateTime? recurrenceEnd,
  }) => CalendarEvent(
    id: id ?? this.id,
    title: title ?? this.title,
    date: date ?? this.date,
    time: time ?? this.time,
    notes: notes ?? this.notes,
    category: category ?? this.category,
    recurrence: recurrence ?? this.recurrence,
    recurrenceEnd: recurrenceEnd ?? this.recurrenceEnd,
  );
}

class CalendarProvider extends ChangeNotifier {
  final NotificationService? _notificationService;
  List<CalendarEvent> _events = [];
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _categoryFilter = 'all';

  List<CalendarEvent> get events => _events;
  DateTime get currentMonth => _currentMonth;
  DateTime get selectedDate => _selectedDate;
  bool get loading => _loading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get categoryFilter => _categoryFilter;

  List<CalendarEvent> get filteredEvents {
    var result = _events;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result =
          result
              .where(
                (e) =>
                    e.title.toLowerCase().contains(query) ||
                    e.notes.toLowerCase().contains(query),
              )
              .toList();
    }
    if (_categoryFilter != 'all') {
      result = result.where((e) => e.category == _categoryFilter).toList();
    }
    return result;
  }

  CalendarProvider({NotificationService? notificationService})
    : _notificationService = notificationService {
    Future.microtask(() => load().then((_) => _scheduleAllFutureEvents()));
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    if (date.year != _currentMonth.year || date.month != _currentMonth.month) {
      _currentMonth = DateTime(date.year, date.month);
      load();
    } else {
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void clearCategoryFilter() {
    _categoryFilter = 'all';
    notifyListeners();
  }

  void previousMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    load();
  }

  void nextMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    load();
  }

  void jumpToToday() {
    _selectedDate = DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    load();
  }

  List<CalendarEvent> eventsForDay(DateTime day) =>
      filteredEvents
          .where(
            (e) =>
                e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day,
          )
          .toList();

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      final start = DateFormat('yyyy-MM-dd').format(_currentMonth);
      final end = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(_currentMonth.year, _currentMonth.month + 1, 0));
      final maps = await db.query(
        'calendar_events',
        where: 'date >= ? AND date <= ?',
        whereArgs: [start, end],
        orderBy: 'date, time',
      );
      _events = maps.map((m) => CalendarEvent.fromMap(m)).toList();
    } catch (e) {
      _error = 'Failed to load events';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _scheduleAllFutureEvents() async {
    final ns = _notificationService;
    if (ns == null) return;
    try {
      final db = await AppDatabase.instance.database;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final maps = await db.query(
        'calendar_events',
        where: 'date >= ?',
        whereArgs: [todayStr],
      );
      final futureEvents = maps.map((m) => CalendarEvent.fromMap(m)).toList();
      for (final event in futureEvents) {
        await _scheduleEventNotification(event);
      }
    } catch (_) {}
  }

  Future<void> _scheduleEventNotification(CalendarEvent event) async {
    final ns = _notificationService;
    if (ns == null || event.id == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('event_reminders_enabled') ?? true;
      final masterEnabled = prefs.getBool('notifications_enabled') ?? true;
      if (!enabled || !masterEnabled) return;
    } catch (_) {}

    DateTime? alertTime;
    if (event.time != null) {
      final parts = event.time!.split(':');
      if (parts.length != 2) return;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return;
      alertTime = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        hour,
        minute,
      );
    } else {
      alertTime = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        9,
        0,
      );
    }

    final scheduled = tz.TZDateTime.from(alertTime, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    final recurrenceComponents = switch (event.recurrence) {
      'daily' => DateTimeComponents.time,
      'weekly' => DateTimeComponents.dayOfWeekAndTime,
      'monthly' => DateTimeComponents.dayOfMonthAndTime,
      _ => null,
    };

    try {
      await ns.zonedSchedule(
        10000 + event.id!,
        'Event Alert: ${event.title}',
        event.notes.isEmpty ? 'Calendar Event Today' : event.notes,
        scheduled,
        NotificationService.eventDetails,
        matchDateTimeComponents: recurrenceComponents,
      );
    } catch (_) {}
  }

  void _cancelEventNotification(int id) {
    _notificationService?.cancel(10000 + id);
  }

  Future<void> save(CalendarEvent event) async {
    try {
      final db = await AppDatabase.instance.database;
      if (event.id == null) {
        final id = await db.insert(
          'calendar_events',
          event.toMap()..remove('id'),
        );
        await _scheduleEventNotification(event.copyWith(id: id));
      } else {
        await db.update(
          'calendar_events',
          event.toMap(),
          where: 'id = ?',
          whereArgs: [event.id],
        );
        _cancelEventNotification(event.id!);
        await _scheduleEventNotification(event);
      }
    } catch (e) {
      _error = 'Failed to save event';
      notifyListeners();
      return;
    }
    await load();
  }

  Future<void> delete(int id) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
      _cancelEventNotification(id);
    } catch (e) {
      _error = 'Failed to delete event';
      notifyListeners();
      return;
    }
    await load();
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _showSearch = false;
  CalendarViewMode _viewMode = CalendarViewMode.month;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CalendarProvider>();
    final isTodaySelected = DateUtils.isSameDay(
      provider.selectedDate,
      DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title:
            _showSearch
                ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: theme.textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Search events...',
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => provider.setSearchQuery(v),
                )
                : const Text(
                  'Calendar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        actions: [
          if (!_showSearch && !isTodaySelected)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ActionChip(
                avatar: Icon(
                  Icons.today_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: const Text('Today'),
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
                backgroundColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.4,
                ),
                side: BorderSide.none,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  provider.jumpToToday();
                },
              ),
            ),
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
            ),
            tooltip: _showSearch ? 'Close search' : 'Search events',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  provider.clearSearch();
                }
              });
            },
          ),
          if (!_showSearch)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list_rounded),
              tooltip: 'Filter by category',
              onSelected: (v) {
                HapticFeedback.selectionClick();
                provider.setCategoryFilter(v);
              },
              itemBuilder: (ctx) {
                final cats = ['all', ..._calendarCategories];
                final current = provider.categoryFilter;
                return cats
                    .map(
                      (c) => PopupMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            if (c == current)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: theme.colorScheme.primary,
                              )
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 8),
                            if (c != 'all')
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: _categoryColor(c, theme),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              c == 'all' ? 'All Categories' : c,
                              style: TextStyle(
                                fontWeight:
                                    c == current
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList();
              },
            ),
        ],
      ),
      body: Consumer2<CalendarProvider, SettingsProvider>(
        builder: (context, provider, settings, _) {
          final weekStartsMonday = settings.weekStartsMonday;

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    provider.error!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      provider.load();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.loading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text(
                    'Loading calendar...',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              if (provider.searchQuery.isNotEmpty ||
                  provider.categoryFilter != 'all')
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        provider.searchQuery.isNotEmpty
                            ? Icons.search_rounded
                            : Icons.filter_alt_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.searchQuery.isNotEmpty
                              ? 'Search: "${provider.searchQuery}"'
                              : 'Filter: ${provider.categoryFilter}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          provider.clearSearch();
                          provider.clearCategoryFilter();
                          _searchController.clear();
                          setState(() => _showSearch = false);
                        },
                        child: Icon(
                          Icons.cancel_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

              // Mode View Selector Pills
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _ViewSegmentTab(
                        label: 'Month',
                        icon: Icons.calendar_month_rounded,
                        isSelected: _viewMode == CalendarViewMode.month,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _viewMode = CalendarViewMode.month);
                        },
                      ),
                      _ViewSegmentTab(
                        label: 'Week',
                        icon: Icons.view_week_rounded,
                        isSelected: _viewMode == CalendarViewMode.week,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _viewMode = CalendarViewMode.week);
                        },
                      ),
                      _ViewSegmentTab(
                        label: 'Day',
                        icon: Icons.view_day_rounded,
                        isSelected: _viewMode == CalendarViewMode.day,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _viewMode = CalendarViewMode.day);
                        },
                      ),
                      _ViewSegmentTab(
                        label: 'Agenda',
                        icon: Icons.view_agenda_rounded,
                        isSelected: _viewMode == CalendarViewMode.agenda,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _viewMode = CalendarViewMode.agenda);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              _MonthHeader(provider: provider),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.98,
                          end: 1.0,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: switch (_viewMode) {
                    CalendarViewMode.month => _MonthViewContent(
                      key: const ValueKey('month_view'),
                      provider: provider,
                      weekStartsMonday: weekStartsMonday,
                    ),
                    CalendarViewMode.week => _WeekViewContent(
                      key: const ValueKey('week_view'),
                      provider: provider,
                      weekStartsMonday: weekStartsMonday,
                    ),
                    CalendarViewMode.day => _DayViewContent(
                      key: const ValueKey('day_view'),
                      provider: provider,
                    ),
                    CalendarViewMode.agenda => _AgendaViewContent(
                      key: const ValueKey('agenda_view'),
                      provider: provider,
                    ),
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'calendar_fab',
        tooltip: 'Add new event',
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Event',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showEventEditor(context, selectedDate: provider.selectedDate);
        },
      ),
    );
  }

  void _showEventEditor(
    BuildContext context, {
    CalendarEvent? event,
    DateTime? selectedDate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventEditor(event: event, selectedDate: selectedDate),
    );
  }
}

class _ViewSegmentTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewSegmentTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color:
                      isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color:
                        isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final CalendarProvider provider;
  const _MonthHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(provider.currentMonth),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  provider.previousMonth();
                },
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  provider.nextMonth();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayNamesHeader extends StatelessWidget {
  final bool weekStartsMonday;
  const _DayNamesHeader({required this.weekStartsMonday});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days =
        weekStartsMonday
            ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
            : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children:
            days.map((d) {
              final isWeekend = d == 'Sat' || d == 'Sun';
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          isWeekend
                              ? theme.colorScheme.primary.withValues(alpha: 0.8)
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _MonthViewContent extends StatelessWidget {
  final CalendarProvider provider;
  final bool weekStartsMonday;

  const _MonthViewContent({
    super.key,
    required this.provider,
    required this.weekStartsMonday,
  });

  @override
  Widget build(BuildContext context) {
    final selectedEvents = provider.eventsForDay(provider.selectedDate);

    return Column(
      children: [
        _DayNamesHeader(weekStartsMonday: weekStartsMonday),
        _MonthGrid(provider: provider, weekStartsMonday: weekStartsMonday),
        const Divider(height: 1, indent: 16, endIndent: 16),
        Expanded(
          child: _AgendaTimelineList(
            date: provider.selectedDate,
            events: selectedEvents,
            provider: provider,
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final CalendarProvider provider;
  final bool weekStartsMonday;
  const _MonthGrid({required this.provider, this.weekStartsMonday = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentMonth = provider.currentMonth;
    final first = DateTime(currentMonth.year, currentMonth.month, 1);
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final prevMonthDays =
        DateTime(currentMonth.year, currentMonth.month, 0).day;

    final startWeekday =
        weekStartsMonday
            ? first.weekday
            : ((first.weekday == 7) ? 1 : first.weekday + 1);

    final leadingDaysCount = startWeekday - 1;
    final totalCells = ((leadingDaysCount + daysInMonth) / 7.0).ceil() * 7;
    final today = DateTime.now();

    final cells = <Widget>[];

    // Leading days from previous month
    for (int i = leadingDaysCount - 1; i >= 0; i--) {
      final dayNum = prevMonthDays - i;
      final date = DateTime(currentMonth.year, currentMonth.month - 1, dayNum);
      cells.add(
        _buildDayCell(
          context,
          theme,
          date,
          dayNum,
          isCurrentMonth: false,
          today: today,
        ),
      );
    }

    // Days in current month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      cells.add(
        _buildDayCell(
          context,
          theme,
          date,
          day,
          isCurrentMonth: true,
          today: today,
        ),
      );
    }

    // Trailing days for next month
    final trailingDaysCount = totalCells - cells.length;
    for (int day = 1; day <= trailingDaysCount; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month + 1, day);
      cells.add(
        _buildDayCell(
          context,
          theme,
          date,
          day,
          isCurrentMonth: false,
          today: today,
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 7 / (totalCells / 7),
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        children: cells,
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    ThemeData theme,
    DateTime date,
    int day, {
    required bool isCurrentMonth,
    required DateTime today,
  }) {
    final events = provider.eventsForDay(date);
    final hasEvent = events.isNotEmpty;
    final isToday = DateUtils.isSameDay(date, today);
    final isSelected = DateUtils.isSameDay(date, provider.selectedDate);

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${DateFormat('EEEE, MMMM d').format(date)}${hasEvent ? ', ${events.length} events' : ''}',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          provider.setSelectedDate(date);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isToday
                            ? theme.colorScheme.primary
                            : (isSelected
                                ? theme.colorScheme.primaryContainer
                                : Colors.transparent),
                    boxShadow:
                        isToday
                            ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.38,
                                ),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                            : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            (isToday || isSelected)
                                ? FontWeight.bold
                                : FontWeight.w500,
                        color:
                            isToday
                                ? theme.colorScheme.onPrimary
                                : (isCurrentMonth
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.outline.withValues(
                                      alpha: 0.5,
                                    )),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 6,
                  child:
                      hasEvent
                          ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...events
                                  .take(3)
                                  .map(
                                    (e) => Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isCurrentMonth
                                                ? _categoryColor(
                                                  e.category,
                                                  theme,
                                                )
                                                : _categoryColor(
                                                  e.category,
                                                  theme,
                                                ).withValues(alpha: 0.4),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              if (events.length > 3)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(left: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          )
                          : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekViewContent extends StatelessWidget {
  final CalendarProvider provider;
  final bool weekStartsMonday;

  const _WeekViewContent({
    super.key,
    required this.provider,
    required this.weekStartsMonday,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = provider.selectedDate;

    final startOfWeek = selected.subtract(
      Duration(
        days:
            weekStartsMonday ? (selected.weekday - 1) : (selected.weekday % 7),
      ),
    );

    final weekDays = List.generate(
      7,
      (i) => startOfWeek.add(Duration(days: i)),
    );

    final dayEvents = provider.eventsForDay(selected);

    return Column(
      children: [
        // 7-day strip
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          color: theme.colorScheme.surfaceContainerLow,
          child: Row(
            children:
                weekDays.map((date) {
                  final isSelected = DateUtils.isSameDay(date, selected);
                  final isToday = DateUtils.isSameDay(date, DateTime.now());
                  final hasEvents = provider.eventsForDay(date).isNotEmpty;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        provider.setSelectedDate(date);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? theme.colorScheme.primary
                                  : (isToday
                                      ? theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.5)
                                      : Colors.transparent),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('E').format(date),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    isSelected
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    hasEvents
                                        ? (isSelected
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.primary)
                                        : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        Expanded(
          child: _AgendaTimelineList(
            date: selected,
            events: dayEvents,
            provider: provider,
          ),
        ),
      ],
    );
  }
}

class _DayViewContent extends StatelessWidget {
  final CalendarProvider provider;
  const _DayViewContent({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = provider.selectedDate;
    final events = provider.eventsForDay(day);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.surfaceContainerLowest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(day),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 24,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, hour) {
              final hourFormatted = '${hour.toString().padLeft(2, '0')}:00';
              final hourEvents =
                  events.where((e) {
                    if (e.time == null) return hour == 9;
                    final h = int.tryParse(e.time!.split(':')[0]);
                    return h == hour;
                  }).toList();

              return Container(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        hourFormatted,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              hourEvents.map((e) {
                                final catColor = _categoryColor(
                                  e.category,
                                  theme,
                                );
                                return Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.only(
                                    bottom: 6,
                                    right: 16,
                                    top: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: catColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  color: catColor.withValues(alpha: 0.1),
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(
                                      _categoryIcon(e.category),
                                      color: catColor,
                                    ),
                                    title: Text(
                                      e.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (e.time != null) e.time!,
                                        e.category,
                                      ].join(' · '),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => EventEditor(event: e),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AgendaViewContent extends StatelessWidget {
  final CalendarProvider provider;
  const _AgendaViewContent({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final allEvents = provider.filteredEvents;

    if (allEvents.isEmpty) {
      return _EmptyAgendaView(
        date: provider.selectedDate,
        onAdd: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => EventEditor(selectedDate: provider.selectedDate),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allEvents.length,
      itemBuilder: (context, index) {
        final e = allEvents[index];
        return _AgendaEventCard(
          event: e,
          provider: provider,
          showDateHeader:
              index == 0 ||
              !DateUtils.isSameDay(allEvents[index - 1].date, e.date),
        );
      },
    );
  }
}

class _AgendaTimelineList extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final CalendarProvider provider;

  const _AgendaTimelineList({
    required this.date,
    required this.events,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (events.isEmpty) {
      return _EmptyAgendaView(
        date: date,
        onAdd: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => EventEditor(selectedDate: date),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: events.length,
      itemBuilder: (ctx, index) {
        final e = events[index];
        final catColor = _categoryColor(e.category, theme);
        final isLast = index == events.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline connector node
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        color: catColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: catColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Dismissible(
                    key: ValueKey('timeline_${e.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    onDismissed: (_) {
                      HapticFeedback.lightImpact();
                      provider.delete(e.id!);
                      if (context.mounted) {
                        showActionSnackBar(
                          context,
                          'Event "${e.title}" deleted',
                          actionLabel: 'Undo',
                          onAction: () => provider.save(e),
                        );
                      }
                    },
                    child: Material(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => EventEditor(event: e),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.title,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _categoryIcon(e.category),
                                          size: 12,
                                          color: catColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          e.category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: catColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    e.time ?? 'All day',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                  if (e.recurrence != 'none') ...[
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.repeat_rounded,
                                      size: 14,
                                      color: theme.colorScheme.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      e.recurrence.capitalize(),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (e.notes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  e.notes,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AgendaEventCard extends StatelessWidget {
  final CalendarEvent event;
  final CalendarProvider provider;
  final bool showDateHeader;

  const _AgendaEventCard({
    required this.event,
    required this.provider,
    required this.showDateHeader,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = _categoryColor(event.category, theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDateHeader)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              DateFormat('EEEE, MMMM d, yyyy').format(event.date),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: catColor.withValues(alpha: 0.2),
              child: Icon(
                _categoryIcon(event.category),
                color: catColor,
                size: 20,
              ),
            ),
            title: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              [
                event.time ?? 'All day',
                event.category,
                if (event.recurrence != 'none') 'Repeats ${event.recurrence}',
              ].join(' · '),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () {
                HapticFeedback.selectionClick();
                _showActionMenu(context);
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Edit Event'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => EventEditor(event: event),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_rounded,
                    color: Theme.of(ctx).colorScheme.error,
                  ),
                  title: Text(
                    'Delete Event',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Delete Event'),
            content: Text('Are you sure you want to delete "${event.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx);
                  provider.delete(event.id!);
                  if (context.mounted) {
                    showActionSnackBar(
                      context,
                      'Event "${event.title}" deleted',
                      actionLabel: 'Undo',
                      onAction: () => provider.save(event),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}

class _EmptyAgendaView extends StatelessWidget {
  final DateTime date;
  final VoidCallback onAdd;

  const _EmptyAgendaView({required this.date, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No events planned',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap below to add an event for ${DateFormat('MMM d').format(date)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Event'),
            ),
          ],
        ),
      ),
    );
  }
}

class EventEditor extends StatefulWidget {
  final CalendarEvent? event;
  final DateTime? selectedDate;
  const EventEditor({super.key, this.event, this.selectedDate});

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late TextEditingController _titleCtrl;
  late TextEditingController _notesCtrl;
  late DateTime _date;
  late String _category;
  late String _recurrence;
  DateTime? _recurrenceEnd;
  TimeOfDay? _time;
  bool _isAllDay = false;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.event?.title ?? '');
    _notesCtrl = TextEditingController(text: widget.event?.notes ?? '');
    _date = widget.event?.date ?? widget.selectedDate ?? DateTime.now();
    _category = widget.event?.category ?? _calendarCategories.first;
    _recurrence = widget.event?.recurrence ?? 'none';
    _recurrenceEnd = widget.event?.recurrenceEnd;

    if (widget.event?.time != null) {
      final parts = widget.event!.time!.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } else if (widget.event == null) {
      _time = TimeOfDay(hour: (DateTime.now().hour + 1) % 24, minute: 0);
      _isAllDay = false;
    } else {
      _isAllDay = true;
    }

    _titleCtrl.addListener(_onTitleChanged);
    _notesCtrl.addListener(_onNotesChanged);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTitleChanged);
    _notesCtrl.removeListener(_onNotesChanged);
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    setState(() {
      if (_titleCtrl.text.trim().isEmpty) {
        _titleError = 'Title is required';
      } else if (_titleCtrl.text.length > _maxTitleLength) {
        _titleError = 'Title is too long';
      } else {
        _titleError = null;
      }
    });
  }

  void _onNotesChanged() {
    setState(() {});
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _time = picked;
        _isAllDay = false;
      });
    }
  }

  Future<void> _pickRecurrenceEnd() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEnd ?? _date.add(const Duration(days: 30)),
      firstDate: _date,
      lastDate: _date.add(const Duration(days: 365 * 10)),
    );
    if (picked != null && mounted) setState(() => _recurrenceEnd = picked);
  }

  bool _hasUnsavedChanges() {
    final originalTitle = widget.event?.title ?? '';
    final originalNotes = widget.event?.notes ?? '';
    final originalDate =
        widget.event?.date ?? widget.selectedDate ?? DateTime.now();
    final originalCategory =
        widget.event?.category ?? _calendarCategories.first;
    final originalRecurrence = widget.event?.recurrence ?? 'none';
    final originalRecurrenceEnd = widget.event?.recurrenceEnd;

    String? originalTimeStr = widget.event?.time;
    final currentTimeStr =
        (!_isAllDay && _time != null)
            ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
            : null;

    return _titleCtrl.text != originalTitle ||
        _notesCtrl.text != originalNotes ||
        !DateUtils.isSameDay(_date, originalDate) ||
        currentTimeStr != originalTimeStr ||
        _category != originalCategory ||
        _recurrence != originalRecurrence ||
        _recurrenceEnd != originalRecurrenceEnd;
  }

  void _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Title is required');
      return;
    }
    if (title.length > _maxTitleLength) {
      setState(() => _titleError = 'Title is too long');
      return;
    }
    HapticFeedback.mediumImpact();
    final provider = context.read<CalendarProvider>();
    final event = CalendarEvent(
      id: widget.event?.id,
      title: title,
      date: _date,
      time:
          (!_isAllDay && _time != null)
              ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
              : null,
      notes: _notesCtrl.text,
      category: _category,
      recurrence: _recurrence,
      recurrenceEnd: _recurrence != 'none' ? _recurrenceEnd : null,
    );
    await provider.save(event);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('Discard changes?'),
                content: const Text(
                  'You have unsaved edits. Are you sure you want to discard them?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep Editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Discard'),
                  ),
                ],
              ),
        );
        if (discard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bottom sheet drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.event == null ? 'New Event' : 'Edit Event',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title input
                TextField(
                  controller: _titleCtrl,
                  autofocus: widget.event == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    hintText: 'Add title',
                    prefixIcon: const Icon(Icons.title_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    errorText: _titleError,
                    counterText: '${_titleCtrl.text.length}/$_maxTitleLength',
                  ),
                  maxLength: _maxTitleLength,
                ),
                const SizedBox(height: 12),

                // Date & Time pickers
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  DateFormat('MMM d, yyyy').format(_date),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _pickDate,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  _isAllDay
                                      ? 'All Day'
                                      : (_time != null
                                          ? _time!.format(context)
                                          : 'Add time'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _pickTime,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'All-day Event',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Switch(
                              value: _isAllDay,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isAllDay = val;
                                  if (val) _time = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Category Choice Chips
                Text(
                  'Category',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _calendarCategories.map((cat) {
                        final isSelected = _category == cat;
                        final color = _categoryColor(cat, theme);
                        return ChoiceChip(
                          selected: isSelected,
                          avatar: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(cat),
                          selectedColor: color.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              HapticFeedback.selectionClick();
                              setState(() => _category = cat);
                            }
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),

                // Recurrence Choice Chips
                Text(
                  'Recurrence',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _recurrenceOptions.asMap().entries.map((entry) {
                        final key = entry.value;
                        final label = _recurrenceLabels[entry.key];
                        final isSelected = _recurrence == key;
                        return ChoiceChip(
                          selected: isSelected,
                          label: Text(label),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              HapticFeedback.selectionClick();
                              setState(() => _recurrence = key);
                            }
                          },
                        );
                      }).toList(),
                ),

                if (_recurrence != 'none') ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_repeat_rounded, size: 18),
                    label: Text(
                      _recurrenceEnd == null
                          ? 'End Date (Optional)'
                          : 'Until ${DateFormat('MMM d, yyyy').format(_recurrenceEnd!)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _pickRecurrenceEnd,
                  ),
                ],

                const SizedBox(height: 16),

                // Notes input
                TextField(
                  controller: _notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Add description or notes...',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    counterText: '${_notesCtrl.text.length}/$_maxNotesLength',
                  ),
                  maxLines: 3,
                  maxLength: _maxNotesLength,
                ),
                const SizedBox(height: 20),

                // Save button
                FilledButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    widget.event == null ? 'Save Event' : 'Update Event',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
