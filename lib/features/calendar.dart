import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../database.dart';
import 'habits.dart';
import 'notes.dart';
final notifications = FlutterLocalNotificationsPlugin();

class CalendarEvent {
  final int? id;
  final String title;
  final DateTime date;
  final String? time;
  final String category;
  final String notes;

  CalendarEvent({
    this.id,
    required this.title,
    required this.date,
    this.time,
    this.category = 'General',
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'date': DateFormat('yyyy-MM-dd').format(date),
    'time': time,
    'category': category,
    'notes': notes,
  };

  factory CalendarEvent.fromMap(Map<String, dynamic> m) => CalendarEvent(
    id: m['id'],
    title: m['title'] ?? '',
    date: DateTime.parse(m['date']),
    time: m['time'],
    category: m['category'] ?? 'General',
    notes: m['notes'] ?? '',
  );
}

class CalendarProvider extends ChangeNotifier {
  List<CalendarEvent> _events = [];
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  String? _error;

  List<CalendarEvent> get events => _events;
  DateTime get currentMonth => _currentMonth;
  bool get loading => _loading;
  String? get error => _error;

  CalendarProvider() { load(); }

  void previousMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    load();
  }

  void nextMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    load();
  }

  List<CalendarEvent> eventsForDay(DateTime day) =>
    _events.where((e) => e.date.year == day.year && e.date.month == day.month && e.date.day == day.day).toList();

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      final start = DateFormat('yyyy-MM-dd').format(DateTime(_currentMonth.year, _currentMonth.month, 1));
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
        final id = await db.insert('calendar_events', event.toMap()..remove('id'));
        _scheduleNotification(CalendarEvent(id: id, title: event.title, date: event.date, time: event.time, category: event.category, notes: event.notes));
      } else {
        await db.update('calendar_events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
        _scheduleNotification(event);
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
      await notifications.cancel(id);
    } catch (e) {
      _error = 'Failed to delete event';
      notifyListeners();
      return;
    }
    await load();
  }

  void _scheduleNotification(CalendarEvent event) {
    if (event.id == null || event.time == null) return;
    final parts = event.time!.split(':');
    final scheduled = DateTime(event.date.year, event.date.month, event.date.day, int.parse(parts[0]), int.parse(parts[1]));
    if (scheduled.isBefore(DateTime.now())) return;
    unawaited(notifications.zonedSchedule(
      event.id!,
      event.title,
      event.notes.isEmpty ? 'Reminder for your scheduled event' : event.notes,
      tz.TZDateTime.from(scheduled, tz.local),
      const NotificationDetails(android: AndroidNotificationDetails('events', 'Event Reminders')),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    ).catchError((_) {}));
  }
}

Color categoryColor(String cat) {
  switch (cat) {
    case 'Work': return Colors.blue;
    case 'Personal': return Colors.green;
    case 'Urgent': return Colors.red;
    default: return Colors.orange;
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar & Logs', style: theme.textTheme.titleLarge),
      ),
      body: Consumer<CalendarProvider>(
        builder: (context, provider, _) {
          if (provider.error != null) return Center(child: Text(provider.error!, style: TextStyle(color: theme.colorScheme.error)));
          if (provider.loading) return const Center(child: CircularProgressIndicator());
          return Column(
            children: [
              _MonthHeader(provider: provider),
              _DayNames(),
              Expanded(child: _MonthGrid(provider: provider)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showEventEditor(context),
      ),
    );
  }

  void _showEventEditor(BuildContext context, {CalendarEvent? event}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventEditor(event: event),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Previous month', onPressed: provider.previousMonth),
          Text(DateFormat('MMMM yyyy').format(provider.currentMonth), style: theme.textTheme.titleMedium),
          IconButton(icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Next month', onPressed: provider.nextMonth),
        ],
      ),
    );
  }
}

class _DayNames extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: days.map((d) => Expanded(child: Center(child: Text(d, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))))).toList(),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final CalendarProvider provider;
  const _MonthGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitsProvider = context.watch<HabitsProvider>();
    final first = DateTime(provider.currentMonth.year, provider.currentMonth.month, 1);
    final daysInMonth = DateTime(provider.currentMonth.year, provider.currentMonth.month + 1, 0).day;
    final startWeekday = first.weekday;
    final today = DateTime.now();
    final cells = <Widget>[];
    for (int i = 1; i < startWeekday; i++) cells.add(const SizedBox());
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(provider.currentMonth.year, provider.currentMonth.month, day);
      final events = provider.eventsForDay(date);
      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
      bool habitCompleted = false;
      for (final habit in habitsProvider.habits) {
        if (habitsProvider.isCompleted(habit.id!, date)) {
          habitCompleted = true;
          break;
        }
      }
      cells.add(
        GestureDetector(
          onTap: () => _showDayDetail(context, date, provider),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isToday ? theme.colorScheme.primaryContainer : (habitCompleted ? theme.colorScheme.primary.withValues(alpha: 0.06) : null),
              shape: BoxShape.circle,
              border: Border.all(
                color: isToday ? theme.colorScheme.primary : (habitCompleted ? theme.colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isToday || habitCompleted ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? theme.colorScheme.onPrimaryContainer : null,
                    ),
                  ),
                  if (events.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events.take(3).map((e) => Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(color: categoryColor(e.category), shape: BoxShape.circle),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 7,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: cells,
    );
  }

  void _showDayDetail(BuildContext context, DateTime date, CalendarProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayDetailPanel(date: date, provider: provider),
    );
  }
}

class _DayDetailPanel extends StatelessWidget {
  final DateTime date;
  final CalendarProvider provider;
  const _DayDetailPanel({required this.date, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = provider.eventsForDay(date);
    final habitsProvider = context.watch<HabitsProvider>();
    final completedHabits = habitsProvider.habits.where((h) => habitsProvider.isCompleted(h.id!, date)).toList();
    final notesProvider = context.watch<NotesProvider>();
    final dayNotes = notesProvider.notes.where((n) =>
      n.updatedAt.year == date.year && n.updatedAt.month == date.month && n.updatedAt.day == date.day
    ).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
        ),
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(DateFormat('EEEE, MMMM d, yyyy').format(date), style: theme.textTheme.titleLarge),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Events / Reminders', style: theme.textTheme.titleMedium),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 13)),
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => EventEditor(selectedDate: date),
                    );
                  },
                )
              ],
            ),
            if (events.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('No events scheduled.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)))
            else
              ...events.map((e) => Card(
                elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(radius: 8, backgroundColor: categoryColor(e.category)),
                  title: Text(e.title, style: theme.textTheme.titleSmall),
                  subtitle: Text(
                    (e.time != null ? '${e.time!}  •  ' : '') + (e.notes.isNotEmpty ? e.notes : e.category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        tooltip: 'Edit event',
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => EventEditor(event: e),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        tooltip: 'Delete event',
                        onPressed: () => provider.delete(e.id!),
                      ),
                    ],
                  ),
                ),
              )),
            const SizedBox(height: 16),
            const Divider(height: 24),
            Text('Completed Habits', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (completedHabits.isEmpty)
              Text('No habits completed on this day.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: completedHabits.map((h) => Chip(
                  avatar: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  label: Text(h.name),
                )).toList(),
              ),
            const SizedBox(height: 16),
            const Divider(height: 24),
            Text('Notes Updated Today', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (dayNotes.isEmpty)
              Text('No notes edited today.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
            else
              ...dayNotes.map((note) => Card(
                elevation: 0,
                color: Color(note.color).withValues(alpha: 0.5),
                child: ListTile(
                  title: Text(note.title.isEmpty ? 'Untitled' : note.title, style: theme.textTheme.titleSmall),
                  subtitle: Text(plainText(note.content), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
                  },
                ),
              )),
          ],
        ),
      ),
    );
  }
}

// ponytail: top-level plain-text extraction, same approach used in NotesProvider
String plainText(String content) {
  return content.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
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
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.event?.title ?? '');
    _notesCtrl = TextEditingController(text: widget.event?.notes ?? '');
    _date = widget.event?.date ?? widget.selectedDate ?? DateTime.now();
    _selectedCategory = widget.event?.category ?? 'General';
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
    if (!mounted) return;
    if (_titleCtrl.text.isEmpty) return;
    final event = CalendarEvent(
      id: widget.event?.id,
      title: _titleCtrl.text,
      date: _date,
      time: _time != null ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}' : null,
      category: _selectedCategory,
      notes: _notesCtrl.text,
    );
    await context.read<CalendarProvider>().save(event);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ['General', 'Work', 'Personal', 'Urgent'];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Event Scheduler', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Event Title', border: OutlineInputBorder()),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: Text(DateFormat('MMM d, yyyy').format(_date)),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(_time != null ? _time!.format(context) : 'Add time'),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Category', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: categories.map((cat) {
                final isSel = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes / Description', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _save,
              child: const Text('Save Event', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
