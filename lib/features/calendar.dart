import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database.dart';
import 'settings_provider.dart';
import '../services/notification_service.dart';
import '../utils/snackbar_utils.dart';

const _calendarCategories = ['General', 'Work', 'Personal', 'Urgent'];

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
    date: DateTime.parse(m['date']),
    time: m['time'],
    notes: m['notes'] ?? '',
    category: m['category'] ?? 'General',
    recurrence: m['recurrence'] ?? 'none',
    recurrenceEnd:
        m['recurrence_end'] != null
            ? DateTime.parse(m['recurrence_end'])
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
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _categoryFilter = 'all';

  List<CalendarEvent> get events => _events;
  DateTime get currentMonth => _currentMonth;
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
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
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
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'calendar',
            'Event Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title:
            _showSearch
                ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search events...',
                    border: InputBorder.none,
                  ),
                  onChanged:
                      (v) => context.read<CalendarProvider>().setSearchQuery(v),
                )
                : const Text('Calendar'),
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
            ),
            tooltip: _showSearch ? 'Close search' : 'Search events',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  context.read<CalendarProvider>().clearSearch();
                }
              });
            },
          ),
          if (!_showSearch)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list_rounded),
              tooltip: 'Filter by category',
              onSelected: (v) {
                context.read<CalendarProvider>().setCategoryFilter(v);
              },
              itemBuilder: (ctx) {
                final cats = ['all', ..._calendarCategories];
                final current = context.read<CalendarProvider>().categoryFilter;
                return cats
                    .map(
                      (c) => PopupMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            if (c == current)
                              const Icon(Icons.check, size: 18)
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 8),
                            Text(c == 'all' ? 'All Categories' : c),
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
          final theme = Theme.of(context);
          final weekStartsMonday = settings.weekStartsMonday;
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    provider.error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => context.read<CalendarProvider>().load(),
                    icon: const Icon(Icons.refresh, size: 18),
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
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading calendar...'),
                ],
              ),
            );
          }
          return Column(
            children: [
              if (provider.searchQuery.isNotEmpty ||
                  provider.categoryFilter != 'all')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  child: Text(
                    provider.searchQuery.isNotEmpty
                        ? 'Search: "${provider.searchQuery}"'
                        : 'Filter: ${provider.categoryFilter}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              _MonthHeader(provider: provider),
              _DayNames(weekStartsMonday: weekStartsMonday),
              Expanded(
                child: _MonthGrid(
                  provider: provider,
                  weekStartsMonday: weekStartsMonday,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add event',
        child: const Icon(Icons.add),
        onPressed: () => _showEventEditor(context),
      ),
    );
  }

  void _showEventEditor(BuildContext context, {CalendarEvent? event}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventEditor(event: event),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final CalendarProvider provider;
  const _MonthHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: provider.previousMonth,
          ),
          Text(
            DateFormat('MMMM yyyy').format(provider.currentMonth),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            onPressed: provider.nextMonth,
          ),
        ],
      ),
    );
  }
}

class _DayNames extends StatelessWidget {
  final bool weekStartsMonday;
  const _DayNames({this.weekStartsMonday = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days =
        weekStartsMonday
            ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
            : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Row(
      children:
          days
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
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
    final first = DateTime(
      provider.currentMonth.year,
      provider.currentMonth.month,
      1,
    );
    final daysInMonth =
        DateTime(
          provider.currentMonth.year,
          provider.currentMonth.month + 1,
          0,
        ).day;
    final startWeekday =
        weekStartsMonday ? first.weekday : (first.weekday % 7) + 1;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (int i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(
        provider.currentMonth.year,
        provider.currentMonth.month,
        day,
      );
      final hasEvent = provider.eventsForDay(date).isNotEmpty;
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      cells.add(
        Semantics(
          button: true,
          label:
              '${DateFormat('EEEE, MMMM d').format(date)}${hasEvent ? ', has events' : ''}',
          child: GestureDetector(
            onTap: () => _showDayEvents(context, date, provider),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  color: isToday ? theme.colorScheme.primaryContainer : null,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.bold : null,
                        ),
                      ),
                      if (hasEvent)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      childAspectRatio: 1.0,
      children: cells,
    );
  }

  void _showDayEvents(
    BuildContext context,
    DateTime date,
    CalendarProvider provider,
  ) {
    final events = provider.eventsForDay(date);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d').format(date),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close details',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 40,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          const Text('No events on this day'),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: events.length,
                      itemBuilder: (ctx, index) {
                        final e = events[index];
                        return ListTile(
                          title: Text(e.title, overflow: TextOverflow.ellipsis),
                          subtitle: e.time != null ? Text(e.time!) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Edit event',
                                onPressed: () {
                                  Navigator.pop(context);
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => EventEditor(event: e),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                tooltip: 'Delete event',
                                onPressed: () => provider.delete(e.id!),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Event'),
                      onPressed: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => EventEditor(selectedDate: date),
                        );
                      },
                    ),
                  ),
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
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.event?.title ?? '');
    _notesCtrl = TextEditingController(text: widget.event?.notes ?? '');
    _date = widget.event?.date ?? widget.selectedDate ?? DateTime.now();
    _category = widget.event?.category ?? _calendarCategories.first;
    if (widget.event?.time != null) {
      final parts = widget.event!.time!.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  bool _hasUnsavedChanges() {
    final originalTitle = widget.event?.title ?? '';
    final originalNotes = widget.event?.notes ?? '';
    final originalDate =
        widget.event?.date ?? widget.selectedDate ?? DateTime.now();
    final originalCategory =
        widget.event?.category ?? _calendarCategories.first;

    String? originalTimeStr;
    if (widget.event?.time != null) {
      originalTimeStr = widget.event!.time;
    }
    final currentTimeStr =
        _time != null
            ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
            : null;

    final titleChanged = _titleCtrl.text != originalTitle;
    final notesChanged = _notesCtrl.text != originalNotes;
    final dateChanged =
        DateUtils.dateOnly(_date) != DateUtils.dateOnly(originalDate);
    final timeChanged = currentTimeStr != originalTimeStr;

    return titleChanged ||
        notesChanged ||
        dateChanged ||
        timeChanged ||
        _category != originalCategory;
  }

  void _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showErrorSnackBar(context, 'Enter an event title');
      return;
    }
    final provider = context.read<CalendarProvider>();
    final event = CalendarEvent(
      id: widget.event?.id,
      title: title,
      date: _date,
      time:
          _time != null
              ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
              : null,
      notes: _notesCtrl.text,
      category: _category,
      recurrence: widget.event?.recurrence ?? 'none',
      recurrenceEnd: widget.event?.recurrenceEnd,
    );
    await provider.save(event);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Discard event?'),
                content: const Text(
                  'You have unsaved changes. Are you sure you want to discard them?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
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
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat('MMM d, yyyy').format(_date)),
                    onPressed: _pickDate,
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _time != null ? _time!.format(context) : 'Add time',
                    ),
                    onPressed: _pickTime,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items:
                    _calendarCategories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: _save,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
