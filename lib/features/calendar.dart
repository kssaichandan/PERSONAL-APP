import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database.dart';
import 'settings_provider.dart';

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
    'id': id, 'title': title,
    'date': DateFormat('yyyy-MM-dd').format(date),
    'time': time, 'notes': notes,
    'category': category, 'recurrence': recurrence,
    'recurrence_end': recurrenceEnd != null ? DateFormat('yyyy-MM-dd').format(recurrenceEnd!) : null,
  };

  factory CalendarEvent.fromMap(Map<String, dynamic> m) => CalendarEvent(
    id: m['id'], title: m['title'],
    date: DateTime.parse(m['date']),
    time: m['time'], notes: m['notes'] ?? '',
    category: m['category'] ?? 'General',
    recurrence: m['recurrence'] ?? 'none',
    recurrenceEnd: m['recurrence_end'] != null ? DateTime.parse(m['recurrence_end']) : null,
  );
}

class CalendarProvider extends ChangeNotifier {
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
      result = result.where((e) =>
        e.title.toLowerCase().contains(query) ||
        e.notes.toLowerCase().contains(query)
      ).toList();
    }
    if (_categoryFilter != 'all') {
      result = result.where((e) => e.category == _categoryFilter).toList();
    }
    return result;
  }

  CalendarProvider() { load(); }

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

  void previousMonth() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1); load(); }
  void nextMonth() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1); load(); }

  List<CalendarEvent> eventsForDay(DateTime day) =>
    _events.where((e) => e.date.year == day.year && e.date.month == day.month && e.date.day == day.day).toList();

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      final start = DateFormat('yyyy-MM-dd').format(_currentMonth);
      final end = DateFormat('yyyy-MM-dd').format(DateTime(_currentMonth.year, _currentMonth.month + 1, 0));
      final maps = await db.query('calendar_events', where: 'date >= ? AND date <= ?', whereArgs: [start, end], orderBy: 'date, time');
      _events = maps.map((m) => CalendarEvent.fromMap(m)).toList();
    } catch (e) {
      _error = 'Failed to load events';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> save(CalendarEvent event) async {
    try {
      final db = await AppDatabase.instance.database;
      if (event.id == null) {
        await db.insert('calendar_events', event.toMap()..remove('id'));
      } else {
        await db.update('calendar_events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
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
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search events...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => context.read<CalendarProvider>().setSearchQuery(v),
              )
            : const Text('Calendar'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
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
                final cats = ['all', 'General', 'Work', 'Personal', 'Urgent'];
                final current = context.read<CalendarProvider>().categoryFilter;
                return cats.map((c) => PopupMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      if (c == current) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(c == 'all' ? 'All Categories' : c),
                    ],
                  ),
                )).toList();
              },
            ),
        ],
      ),
      body: Consumer2<CalendarProvider, SettingsProvider>(
        builder: (context, provider, settings, _) {
          final theme = Theme.of(context);
          final weekStartsMonday = settings.weekStartsMonday;
          if (provider.error != null) return Center(child: Text(provider.error!, style: TextStyle(color: theme.colorScheme.error)));
          if (provider.loading) return const Center(child: CircularProgressIndicator());
          return Column(
            children: [
              if (provider.searchQuery.isNotEmpty || provider.categoryFilter != 'all')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Text(
                    provider.searchQuery.isNotEmpty
                        ? 'Search: "${provider.searchQuery}"'
                        : 'Filter: ${provider.categoryFilter}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              _MonthHeader(provider: provider),
              _DayNames(weekStartsMonday: weekStartsMonday),
              Expanded(child: _MonthGrid(provider: provider, weekStartsMonday: weekStartsMonday)),
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
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: provider.previousMonth),
          Text(DateFormat('MMMM yyyy').format(provider.currentMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: provider.nextMonth),
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
    final days = weekStartsMonday
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Row(
      children: days.map((d) => Expanded(child: Center(child: Text(d, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500))))).toList(),
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
    final first = DateTime(provider.currentMonth.year, provider.currentMonth.month, 1);
    final daysInMonth = DateTime(provider.currentMonth.year, provider.currentMonth.month + 1, 0).day;
    final startWeekday = weekStartsMonday ? first.weekday : (first.weekday % 7) + 1;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (int i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(provider.currentMonth.year, provider.currentMonth.month, day);
      final hasEvent = provider.eventsForDay(date).isNotEmpty;
      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
      cells.add(
        GestureDetector(
          onTap: () => _showDayEvents(context, date, provider),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isToday ? theme.colorScheme.primaryContainer : null,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$day', style: TextStyle(fontSize: 14, fontWeight: isToday ? FontWeight.bold : null)),
                  if (hasEvent) Container(width: 5, height: 5, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
                ],
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

  void _showDayEvents(BuildContext context, DateTime date, CalendarProvider provider) {
    final events = provider.eventsForDay(date);
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(DateFormat('EEEE, MMMM d').format(date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (events.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No events')),
          ...events.map((e) => ListTile(
            title: Text(e.title, overflow: TextOverflow.ellipsis),
            subtitle: e.time != null ? Text(e.time!) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, size: 18), tooltip: 'Edit', onPressed: () {
                  Navigator.pop(context);
                  showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => EventEditor(event: e));
                }),
                IconButton(icon: const Icon(Icons.delete, size: 18), tooltip: 'Delete', onPressed: () => provider.delete(e.id!)),
              ],
            ),
          )),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Event'),
                onPressed: () {
                  Navigator.pop(context);
                  showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => EventEditor(selectedDate: date));
                },
              ),
            ),
          ),
        ],
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
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.event?.title ?? '');
    _notesCtrl = TextEditingController(text: widget.event?.notes ?? '');
    _date = widget.event?.date ?? widget.selectedDate ?? DateTime.now();
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
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  void _save() async {
    if (_titleCtrl.text.isEmpty) return;
    final provider = context.read<CalendarProvider>();
    final event = CalendarEvent(
      id: widget.event?.id,
      title: _titleCtrl.text,
      date: _date,
      time: _time != null ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}' : null,
      notes: _notesCtrl.text,
    );
    await provider.save(event);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()), autofocus: true),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton.icon(icon: const Icon(Icons.calendar_today), label: Text(DateFormat('MMM d, yyyy').format(_date)), onPressed: _pickDate),
                const SizedBox(height: 4),
                TextButton.icon(icon: const Icon(Icons.access_time), label: Text(_time != null ? _time!.format(context) : 'Add time'), onPressed: _pickTime),
              ],
            ),
            TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 16),
            FilledButton.icon(icon: const Icon(Icons.save), label: const Text('Save'), onPressed: _save),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
