import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../database.dart';
import '../notifications.dart';

class CalendarEvent {
  final int? id;
  final String title;
  final DateTime date;
  final String? time;
  final String notes;

  CalendarEvent({this.id, required this.title, required this.date, this.time, this.notes = ''});

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title,
    'date': DateFormat('yyyy-MM-dd').format(date),
    'time': time, 'notes': notes,
  };

  factory CalendarEvent.fromMap(Map<String, dynamic> m) => CalendarEvent(
    id: m['id'], title: m['title'],
    date: DateTime.parse(m['date']),
    time: m['time'], notes: m['notes'] ?? '',
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
      for (final e in _events) { _scheduleNotification(e); }
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
        _scheduleNotification(CalendarEvent(id: id, title: event.title, date: event.date, time: event.time, notes: event.notes));
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
    unawaited(notifications.zonedSchedule(event.id!, event.title, event.notes.isEmpty ? null : event.notes,
      tz.TZDateTime.from(scheduled, tz.local),
      const NotificationDetails(android: AndroidNotificationDetails('events', 'Event Reminders')),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime));
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Consumer<CalendarProvider>(
        builder: (context, provider, _) {
          if (provider.error != null) return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)));
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
  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: days.map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12))))).toList(),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final CalendarProvider provider;
  const _MonthGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(provider.currentMonth.year, provider.currentMonth.month, 1);
    final daysInMonth = DateTime(provider.currentMonth.year, provider.currentMonth.month + 1, 0).day;
    final startWeekday = first.weekday; // 1=Mon ... 7=Sun
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
              color: isToday ? Theme.of(context).colorScheme.primaryContainer : null,
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
            title: Text(e.title),
            subtitle: e.time != null ? Text(e.time!) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () {
                  Navigator.pop(context);
                  showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => EventEditor(event: e));
                }),
                IconButton(icon: const Icon(Icons.delete, size: 20), onPressed: () => provider.delete(e.id!)),
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
    final event = CalendarEvent(
      id: widget.event?.id,
      title: _titleCtrl.text,
      date: _date,
      time: _time != null ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}' : null,
      notes: _notesCtrl.text,
    );
    await context.read<CalendarProvider>().save(event);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()), autofocus: true),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(icon: const Icon(Icons.calendar_today), label: Text(DateFormat('MMM d, yyyy').format(_date)), onPressed: _pickDate),
              const SizedBox(width: 8),
              TextButton.icon(icon: const Icon(Icons.access_time), label: Text(_time != null ? _time!.format(context) : 'Add time'), onPressed: _pickTime),
            ],
          ),
          TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.save), label: const Text('Save'), onPressed: _save),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
