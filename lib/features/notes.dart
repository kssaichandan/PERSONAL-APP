import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database.dart';
import '../services/notification_service.dart';
import '../utils/text_utils.dart';
import '../utils/snackbar_utils.dart';

class Note {
  final int? id;
  final String title;
  final String content;
  final bool pinned;
  final bool favorite;
  final int? color;
  final bool archived;
  final DateTime? deletedAt;
  final DateTime? reminderTime;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.pinned = false,
    this.favorite = false,
    this.color,
    this.archived = false,
    this.deletedAt,
    this.reminderTime,
    this.priority = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'content': content,
    'pinned': pinned ? 1 : 0,
    'favorite': favorite ? 1 : 0,
    'color': color,
    'archived': archived ? 1 : 0,
    'deleted_at': deletedAt?.toIso8601String(),
    'reminder_time': reminderTime?.toIso8601String(),
    'priority': priority,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'], title: m['title'], content: m['content'],
    pinned: m['pinned'] == 1,
    favorite: m['favorite'] == 1,
    color: m['color'],
    archived: m['archived'] == 1,
    deletedAt: m['deleted_at'] != null ? DateTime.parse(m['deleted_at']) : null,
    reminderTime: m['reminder_time'] != null ? DateTime.parse(m['reminder_time']) : null,
    priority: m['priority'] ?? 0,
    createdAt: DateTime.parse(m['created_at']),
    updatedAt: DateTime.parse(m['updated_at']),
  );

  Note copyWith({int? id, String? title, String? content, bool? pinned, bool? favorite, int? color, bool? archived, DateTime? deletedAt, DateTime? reminderTime, int? priority, DateTime? updatedAt}) => Note(
    id: id ?? this.id, title: title ?? this.title, content: content ?? this.content,
    pinned: pinned ?? this.pinned, favorite: favorite ?? this.favorite,
    color: color ?? this.color, archived: archived ?? this.archived,
    deletedAt: deletedAt ?? this.deletedAt,
    reminderTime: reminderTime ?? this.reminderTime,
    priority: priority ?? this.priority,
    createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
  );
}

String _wordCount(String deltaJson) {
  try {
    final text = deltaToPlainText(deltaJson);
    return '${text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words';
  } catch (_) {
    return '0 words';
  }
}

const _noteColors = <int?>[
  null,
  0xFFFDDDE6, 0xFFFFF3E0, 0xFFFFF9C4, 0xFFC8E6C9,
  0xFFBBDEFB, 0xFFE1BEE7, 0xFFD7CCC8, 0xFFCFD8DC,
  0xFFFFCCBC, 0xFFDCEDC8, 0xFFB2EBF2, 0xFFF0F4C3,
];

class NotesProvider extends ChangeNotifier {
  final NotificationService? _notificationService;
  List<Note> _notes = [];
  List<Note> _filtered = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  Timer? _searchTimer;
  final Set<int> _selectedNotes = {};
  String _selectedTag = '';
  bool _showArchived = false;
  bool _gridView = false;
  String _sortBy = 'updated';

  static const _noteIdOffset = 5000;

  List<Note> get notes {
    var list = _query.isNotEmpty ? _filtered : _notes;
    if (!_showArchived) list = list.where((n) => !n.archived && n.deletedAt == null).toList();
    return _sorted(list);
  }

  List<Note> get archivedNotes => _notes.where((n) => n.archived && n.deletedAt == null).toList();
  List<Note> get trashedNotes => _notes.where((n) => n.deletedAt != null).toList();
  int get trashCount => trashedNotes.length;
  int get totalCount => _notes.where((n) => n.deletedAt == null).length;
  int get pinnedCount => _notes.where((n) => n.pinned && n.deletedAt == null).length;
  int get favoriteCount => _notes.where((n) => n.favorite && n.deletedAt == null).length;

  bool get loading => _loading;
  String? get error => _error;
  String get query => _query;
  Set<int> get selectedNotes => _selectedNotes;
  bool get isSelectionMode => _selectedNotes.isNotEmpty;
  String get selectedTag => _selectedTag;
  bool get showArchived => _showArchived;
  bool get gridView => _gridView;
  String get sortBy => _sortBy;

  NotesProvider({NotificationService? notificationService}) : _notificationService = notificationService { load(); }

  List<Note> _sorted(List<Note> list) {
    switch (_sortBy) {
      case 'created': return List.from(list)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'title': return List.from(list)..sort((a, b) => a.title.compareTo(b.title));
      default: return List.from(list)..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    }
  }

  void setSortBy(String sort) { _sortBy = sort; notifyListeners(); }
  void toggleShowArchived() { _showArchived = !_showArchived; notifyListeners(); }

  void search(String q) {
    _query = q;
    notifyListeners();
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 200), () {
      if (q.isEmpty) { _filtered = []; }
      else { _filtered = _notes.where((n) =>
        n.title.toLowerCase().contains(q.toLowerCase()) ||
        deltaToPlainText(n.content).toLowerCase().contains(q.toLowerCase())
      ).toList(); }
      notifyListeners();
    });
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query('notes', orderBy: 'pinned DESC, updated_at DESC');
      _notes = maps.map((m) => Note.fromMap(m)).toList();
    } catch (e) {
      _error = 'Failed to load notes';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> save(Note note) async {
    try {
      final db = await AppDatabase.instance.database;
      if (note.id == null) {
        final id = await db.insert('notes', note.toMap()..remove('id'));
        if (note.reminderTime != null) _scheduleReminder(note.copyWith(id: id));
      } else {
        await db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
        _rescheduleReminder(note);
      }
    } catch (e) {
      _error = 'Failed to save note';
      debugLog('Failed to save note: $e');
      notifyListeners();
      return;
    }
    await load();
  }

  Future<void> delete(int id) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('notes', where: 'id = ?', whereArgs: [id]);
      _cancelReminder(id);
    } catch (e) {
      _error = 'Failed to delete note';
      debugLog('Failed to delete note: $e');
      notifyListeners();
      return;
    }
    await load();
  }

  Future<void> togglePin(Note note) async {
    await save(note.copyWith(pinned: !note.pinned));
  }

  Future<void> toggleFavorite(Note note) async {
    await save(note.copyWith(favorite: !note.favorite));
  }

  Future<void> setColor(Note note, int? color) async {
    await save(note.copyWith(color: color));
  }

  Future<void> setPriority(Note note, int priority) async {
    await save(note.copyWith(priority: priority));
  }

  Future<void> archive(Note note) async {
    await save(note.copyWith(archived: !note.archived));
  }

  Future<void> trash(Note note) async {
    await save(note.copyWith(deletedAt: DateTime.now()));
  }

  Future<void> restore(Note note) async {
    await save(note.copyWith(deletedAt: null));
  }

  Future<void> duplicate(Note note) async {
    await save(Note(
      title: '${note.title} (copy)',
      content: note.content,
      pinned: false, favorite: false,
      color: note.color, priority: 0,
      archived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> setReminder(Note note, DateTime? time) async {
    await save(note.copyWith(reminderTime: time));
  }

  void _scheduleReminder(Note note) {
    final ns = _notificationService;
    if (ns == null || note.reminderTime == null || note.id == null) return;
    final scheduled = tz.TZDateTime.from(note.reminderTime!, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    ns.zonedSchedule(
      _noteIdOffset + note.id!,
      'Note Reminder: ${note.title}',
      deltaToPlainText(note.content),
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails('notes', 'Note Reminders'),
      ),
    );
  }

  void _rescheduleReminder(Note note) {
    _cancelReminder(note.id);
    _scheduleReminder(note);
  }

  void _cancelReminder(int? id) {
    if (id == null) return;
    _notificationService?.cancel(_noteIdOffset + id);
  }

  void toggleGridView() { _gridView = !_gridView; notifyListeners(); }

  void selectTag(String tag) { _selectedTag = tag; notifyListeners(); }

  void toggleSelection(int id) {
    if (_selectedNotes.contains(id)) { _selectedNotes.remove(id); }
    else { _selectedNotes.add(id); }
    notifyListeners();
  }

  void clearSelection() { _selectedNotes.clear(); notifyListeners(); }

  void selectAll() {
    final ids = notes.map((n) => n.id!).toSet();
    _selectedNotes.addAll(ids);
    notifyListeners();
  }

  Future<void> deleteMultiple() async {
    for (final id in _selectedNotes) { await delete(id); }
    clearSelection();
  }
}

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<NotesProvider>(builder: (_, p, __) => Text(p.isSelectionMode ? '${p.selectedNotes.length} selected' : 'Notes')),
        actions: [
          Consumer<NotesProvider>(builder: (context, p, _) {
            if (p.isSelectionMode) {
              return Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.select_all), tooltip: 'Select all', onPressed: p.selectAll),
                IconButton(icon: const Icon(Icons.delete), tooltip: 'Delete selected', onPressed: () async {
                  final count = p.selectedNotes.length;
                  await p.deleteMultiple();
                  if (context.mounted) showSuccessSnackBar(context, 'Deleted $count notes');
                }),
                IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel', onPressed: p.clearSelection),
              ]);
            }
            return Row(mainAxisSize: MainAxisSize.min, children: [
              if (p.trashCount > 0)
                IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Trash (${p.trashCount})', onPressed: () => _showTrash(context)),
              PopupMenuButton<String>(
                tooltip: 'More options',
                onSelected: (v) {
                  if (v == 'archived') p.toggleShowArchived();
                  else if (v == 'grid') p.toggleGridView();
                  else p.setSortBy(v);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'grid', child: Row(children: [Icon(p.gridView ? Icons.grid_view : Icons.list, size: 18), const SizedBox(width: 8), Text(p.gridView ? 'List view' : 'Grid view')])),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'updated', child: Row(children: [Icon(p.sortBy == 'updated' ? Icons.radio_button_checked : Icons.radio_button_off, size: 18), const SizedBox(width: 8), const Text('Sort by Updated')])),
                  PopupMenuItem(value: 'created', child: Row(children: [Icon(p.sortBy == 'created' ? Icons.radio_button_checked : Icons.radio_button_off, size: 18), const SizedBox(width: 8), const Text('Sort by Created')])),
                  PopupMenuItem(value: 'title', child: Row(children: [Icon(p.sortBy == 'title' ? Icons.radio_button_checked : Icons.radio_button_off, size: 18), const SizedBox(width: 8), const Text('Sort by Title')])),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'archived', child: Row(children: [Icon(p.showArchived ? Icons.check_box : Icons.check_box_outline_blank, size: 18), const SizedBox(width: 8), const Text('Show Archived')])),
                ],
              ),
            ]);
          }),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Consumer<NotesProvider>(builder: (_, p, __) =>
                    p.query.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), tooltip: 'Clear search', onPressed: () => p.search('')) : const SizedBox.shrink()
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: context.read<NotesProvider>().search,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Consumer<NotesProvider>(builder: (_, p, __) =>
                Row(children: [
                  Flexible(child: Text('${p.totalCount} notes', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                  if (p.favoriteCount > 0)
                    Padding(padding: const EdgeInsets.only(left: 12), child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text('${p.favoriteCount}', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                    ])),
                ]),
              ),
            ),
            Expanded(child: Consumer<NotesProvider>(builder: (context, p, _) {
              if (p.error != null) return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 12),
                    Text(p.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () => context.read<NotesProvider>().load(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
              if (p.loading) return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading notes...'),
                  ],
                ),
              );
              if (p.notes.isEmpty) {
                if (p.query.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No matching notes', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Try a different search term', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => context.read<NotesProvider>().search(''),
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Clear search'),
                        ),
                      ],
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.note_add_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No notes yet', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Tap + to create your first note', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }
              final textScale = MediaQuery.textScalerOf(context).textScaleFactor;
              if (p.gridView) {
                return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200, mainAxisSpacing: 12, crossAxisSpacing: 12,
                      childAspectRatio: textScale > 1.2 ? 0.7 : 0.85,
                    ),
                    itemCount: p.notes.length,
                    itemBuilder: (_, i) => _NoteCard(note: p.notes[i], grid: true),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: p.notes.length,
                  itemBuilder: (_, i) => _NoteCard(note: p.notes[i], grid: false),
                );
              })),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create note',
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(provider: context.read<NotesProvider>())));
        },
      ),
    );
  }

  void _showTrash(BuildContext context) {
    final provider = context.read<NotesProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Text('Trash', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${provider.trashCount} notes', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    for (final n in provider.trashedNotes) await provider.delete(n.id!);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text('Empty Trash', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: provider.trashedNotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 48, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        const Text('Trash is empty'),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: provider.trashedNotes.length,
                    itemBuilder: (_, i) {
                      final note = provider.trashedNotes[i];
                      return ListTile(
                        title: Text(note.title.isEmpty ? 'Untitled' : note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(DateFormat.yMMMd().format(note.deletedAt!), style: Theme.of(context).textTheme.bodySmall),
                        leading: const Icon(Icons.delete_outline),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.restore), tooltip: 'Restore', onPressed: () => provider.restore(note)),
                          IconButton(icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error), tooltip: 'Delete permanently', onPressed: () => provider.delete(note.id!)),
                        ]),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final bool grid;
  const _NoteCard({required this.note, required this.grid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<NotesProvider>();

    Color? bg;
    if (note.color != null) {
      bg = Color(note.color!).withValues(alpha: 0.3);
    }

    final card = Card(
      color: bg,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note, provider: provider))),
        child: Padding(
          padding: EdgeInsets.all(grid ? 10 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (note.pinned) Padding(padding: EdgeInsets.only(right: grid ? 2 : 4), child: Icon(Icons.push_pin, size: 14, color: theme.colorScheme.primary)),
                  if (note.favorite) Padding(padding: EdgeInsets.only(right: grid ? 2 : 4), child: Icon(Icons.star, size: 14, color: Colors.amber)),
                  if (note.reminderTime != null) Padding(padding: EdgeInsets.only(right: grid ? 2 : 4), child: Icon(Icons.notifications, size: 14)),
                  if (note.priority > 0 && !grid) ...[
                    const SizedBox(width: 2),
                    ...List.generate(note.priority, (_) => Icon(Icons.flag, size: 14, color: theme.colorScheme.tertiary)),
                  ],
                ])),
                SizedBox(
                  width: 48, height: 48,
                  child: GestureDetector(
                    onTap: () => provider.toggleSelection(note.id!),
                    child: Icon(
                      provider.selectedNotes.contains(note.id) ? Icons.check_circle : Icons.circle_outlined,
                      size: grid ? 18 : 20, color: provider.selectedNotes.contains(note.id) ? theme.colorScheme.primary : theme.colorScheme.outline,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(note.title.isEmpty ? 'Untitled' : note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (!grid) ...[
                const SizedBox(height: 4),
                Text(deltaToPlainText(note.content), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );

    if (grid) return card;
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(color: theme.colorScheme.tertiary, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete_outline, color: Colors.white)),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Move to trash?'),
            content: const Text('You can restore it later from the trash.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trash')),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        provider.trash(note);
        if (context.mounted) showSuccessSnackBar(context, 'Moved to trash');
      },
      child: card,
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final NotesProvider provider;
  const NoteEditorScreen({super.key, this.note, required this.provider});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late QuillController _controller;
  late TextEditingController _titleController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    if (widget.note != null && widget.note!.content.isNotEmpty) {
      try {
        final delta = jsonDecode(widget.note!.content);
        _controller = QuillController(document: Document.fromJson(delta), selection: const TextSelection.collapsed(offset: 0));
      } catch (_) {
        _controller = QuillController.basic();
      }
    } else {
      _controller = QuillController.basic();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final content = jsonEncode(_controller.document.toDelta().toJson());
    final note = Note(
      id: widget.note?.id,
      title: _titleController.text,
      content: content,
      pinned: widget.note?.pinned ?? false,
      favorite: widget.note?.favorite ?? false,
      color: widget.note?.color,
      archived: widget.note?.archived ?? false,
      reminderTime: widget.note?.reminderTime,
      priority: widget.note?.priority ?? 0,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await widget.provider.save(note);
    if (mounted) {
      setState(() => _saving = false);
      showSuccessSnackBar(context, 'Note saved');
      Navigator.pop(context);
    }
  }

  void _share() {
    final text = '${_titleController.text}\n\n${deltaToPlainText(jsonEncode(_controller.document.toDelta().toJson()))}';
    Share.share(text);
  }

  Future<void> _pickReminder() async {
    final initial = widget.note?.reminderTime ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    final reminder = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (reminder.isBefore(DateTime.now())) {
      if (mounted) showErrorSnackBar(context, 'Reminder time must be in the future');
      return;
    }
    final note = (widget.note ?? Note(title: _titleController.text, content: jsonEncode(_controller.document.toDelta().toJson()), createdAt: DateTime.now(), updatedAt: DateTime.now()))
        .copyWith(reminderTime: reminder);
    setState(() {});
    await widget.provider.setReminder(note, reminder);
    if (mounted) showSuccessSnackBar(context, 'Reminder set');
  }

  void _pickColor() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Note Color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _noteColors.map((c) {
              final selected = widget.note?.color == c;
              return Semantics(
                label: c != null ? 'Color $c' : 'No color',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    final note = (widget.note ?? Note(title: _titleController.text, content: jsonEncode(_controller.document.toDelta().toJson()), createdAt: DateTime.now(), updatedAt: DateTime.now()))
                        .copyWith(color: c);
                    widget.provider.setColor(note, c);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: c != null ? Color(c).withValues(alpha: 0.5) : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: selected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
                    ),
                    child: c == null ? const Icon(Icons.block, size: 20) : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  void _duplicate() async {
    await widget.provider.duplicate(widget.note!);
    if (mounted) showSuccessSnackBar(context, 'Note duplicated');
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _wordCount(jsonEncode(_controller.document.toDelta().toJson()));
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none)),
          actions: [
            if (widget.note != null) ...[
              IconButton(icon: Icon(widget.note!.favorite ? Icons.star : Icons.star_border, color: widget.note!.favorite ? Colors.amber : null), tooltip: 'Favorite', onPressed: () {
                widget.provider.toggleFavorite(widget.note!);
                setState(() {});
              }),
              IconButton(icon: const Icon(Icons.color_lens_outlined), tooltip: 'Color', onPressed: _pickColor),
              IconButton(icon: const Icon(Icons.notifications_outlined), tooltip: widget.note!.reminderTime != null ? 'Reminder set' : 'Set reminder',
                onPressed: _pickReminder, color: widget.note!.reminderTime != null ? Theme.of(context).colorScheme.primary : null),
              PopupMenuButton(tooltip: 'More', onSelected: (v) {
                if (v == 'duplicate') _duplicate();
                else if (v == 'share') _share();
                else if (v == 'pin') { widget.provider.togglePin(widget.note!); setState(() {}); }
                else if (v == 'archive') { widget.provider.archive(widget.note!); if (mounted) Navigator.pop(context); }
              }, itemBuilder: (_) => [
                PopupMenuItem(value: 'pin', child: Text(widget.note!.pinned ? 'Unpin' : 'Pin')),
                PopupMenuItem(value: 'duplicate', child: const Text('Duplicate')),
                PopupMenuItem(value: 'share', child: const Text('Share')),
                PopupMenuItem(value: 'archive', child: Text(widget.note!.archived ? 'Unarchive' : 'Archive')),
              ]),
            ],
            IconButton(icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), tooltip: 'Save', onPressed: _saving ? null : _save),
          ],
        ),
        body: Column(
          children: [
            QuillSimpleToolbar(
              controller: _controller,
              config: const QuillSimpleToolbarConfig(
                showBackgroundColorButton: false,
                showColorButton: false,
                showSubscript: false,
                showSuperscript: false,
                showInlineCode: false,
                showCodeBlock: false,
                showIndent: false,
                showDirection: false,
                showLink: false,
                showSearchButton: false,
                showFontFamily: false,
                showFontSize: false,
                showSmallButton: false,
                showAlignmentButtons: false,
                showLineHeightButton: false,
              ),
            ),
            Expanded(child: QuillEditor.basic(controller: _controller)),
            if (widget.note != null && widget.note!.reminderTime != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Row(children: [
                  const Icon(Icons.notifications, size: 14),
                  const SizedBox(width: 6),
                  Text('Reminder: ${DateFormat.yMMMd().add_jm().format(widget.note!.reminderTime!)}', style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  SizedBox(
                    width: 48, height: 48,
                    child: GestureDetector(
                      onTap: () async {
                        final note = widget.note!.copyWith(reminderTime: null);
                        await widget.provider.setReminder(note, null);
                        if (mounted) setState(() {});
                      },
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ]),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
              ),
              child: Row(children: [
                Text(wordCount, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (widget.note != null) ...[
                  const Spacer(),
                  Text('Created: ${DateFormat.yMMMd().add_jm().format(widget.note!.createdAt)}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  ThemeData get theme => Theme.of(context);
}
