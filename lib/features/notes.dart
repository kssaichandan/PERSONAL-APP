import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../database.dart';

class Note {
  final int? id;
  final String title;
  final String content;
  final int color;
  final bool pinned;
  final String tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.color = 0xFFFFFFFF,
    this.pinned = false,
    this.tags = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'color': color,
    'pinned': pinned ? 1 : 0,
    'tags': tags,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'],
    title: m['title'] ?? '',
    content: m['content'] ?? '',
    color: m['color'] ?? 0xFFFFFFFF,
    pinned: m['pinned'] == 1,
    tags: m['tags'] ?? '',
    createdAt: DateTime.parse(m['created_at']),
    updatedAt: DateTime.parse(m['updated_at']),
  );
}

class NotesProvider extends ChangeNotifier {
  List<Note> _notes = [];
  List<Note> _filtered = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _selectedTag = 'All';

  List<Note> get notes {
    List<Note> source = _query.isNotEmpty ? _filtered : _notes;
    if (_selectedTag == 'All') return source;
    return source.where((n) => n.tags.split(',').map((t) => t.trim()).contains(_selectedTag)).toList();
  }

  bool get loading => _loading;
  String? get error => _error;
  String get query => _query;
  String get selectedTag => _selectedTag;

  List<String> get allTags {
    final tagsSet = {'All'};
    for (final note in _notes) {
      if (note.tags.isNotEmpty) {
        for (final tag in note.tags.split(',')) {
          if (tag.trim().isNotEmpty) tagsSet.add(tag.trim());
        }
      }
    }
    return tagsSet.toList();
  }

  NotesProvider() { load(); }

  void search(String q) {
    _query = q;
    if (q.isEmpty) {
      _filtered = [];
    } else {
      _filtered = _notes.where((n) =>
        n.title.toLowerCase().contains(q.toLowerCase()) ||
        n.content.toLowerCase().contains(q.toLowerCase())
      ).toList();
    }
    notifyListeners();
  }

  void selectTag(String tag) {
    _selectedTag = tag;
    notifyListeners();
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

  Future<int> save(Note note) async {
    int noteId = note.id ?? 0;
    try {
      final db = await AppDatabase.instance.database;
      if (note.id == null) {
        noteId = await db.insert('notes', note.toMap()..remove('id'));
      } else {
        await db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
      }
    } catch (e) {
      _error = 'Failed to save note';
      notifyListeners();
      return noteId;
    }
    await load();
    return noteId;
  }

  Future<void> delete(int id) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      _error = 'Failed to delete note';
      notifyListeners();
      return;
    }
    await load();
  }

  Future<void> togglePin(Note note) async {
    await save(Note(
      id: note.id, title: note.title, content: note.content,
      color: note.color, pinned: !note.pinned, tags: note.tags,
      createdAt: note.createdAt, updatedAt: DateTime.now(),
    ));
  }
}

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes', style: theme.textTheme.titleLarge),
      ),
      body: Consumer<NotesProvider>(
        builder: (context, provider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: provider.query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => provider.search(''),
                          tooltip: 'Clear search',
                        )
                      : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainer,
                    isDense: true,
                  ),
                  onChanged: provider.search,
                ),
              ),
              if (provider.allTags.length > 1)
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.allTags.length,
                    itemBuilder: (context, i) {
                      final tag = provider.allTags[i];
                      final isSel = provider.selectedTag == tag;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tag, style: theme.textTheme.bodySmall),
                          selected: isSel,
                          onSelected: (_) => provider.selectTag(tag),
                        ),
                      );
                    },
                  ),
                ),
              Expanded(child: _buildGrid(context, provider)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditorScreen())),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, NotesProvider provider) {
    final theme = Theme.of(context);
    if (provider.error != null) {
      return Center(child: Text(provider.error!, style: TextStyle(color: theme.colorScheme.error)));
    }
    if (provider.loading) return const Center(child: CircularProgressIndicator());
    if (provider.notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notes_rounded, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              provider.query.isNotEmpty ? 'No matching notes' : 'No notes yet',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: provider.notes.length,
      itemBuilder: (context, i) {
        final note = provider.notes[i];
        final color = Color(note.color);
        final isDarkNote = color.computeLuminance() < 0.5;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note))),
          child: Card(
            elevation: 1,
            color: color,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Untitled' : note.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkNote ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.pinned)
                        Icon(Icons.push_pin, size: 14, color: isDarkNote ? Colors.white70 : Colors.black54),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      note.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkNote ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMM d').format(note.updatedAt),
                    style: TextStyle(fontSize: 10, color: isDarkNote ? Colors.white38 : Colors.black38),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagsController;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _tagsController = TextEditingController(text: widget.note?.tags ?? '');
    _selectedColor = widget.note?.color ?? 0xFFFFFFFF;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<int> _saveNoteSilent() async {
    final note = Note(
      id: widget.note?.id,
      title: _titleController.text,
      content: _contentController.text,
      color: _selectedColor,
      pinned: widget.note?.pinned ?? false,
      tags: _tagsController.text,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (!mounted) return 0;
    return context.read<NotesProvider>().save(note);
  }

  void _save() async {
    await _saveNoteSilent();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorsList = [
      0xFFFFFFFF,
      0xFFF28B82,
      0xFFFBBC04,
      0xFFFFF475,
      0xFFCCFF90,
      0xFFA7FFEB,
      0xFFCBF0F8,
      0xD7AECFC9,
      0xFFD7AEFB,
      0xFFFDCFE8,
    ];

    return Scaffold(
      backgroundColor: Color(_selectedColor),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Change color',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => Container(
                  height: 100,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: colorsList.length,
                    itemBuilder: (context, i) {
                      final c = colorsList[i];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedColor = c);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 48,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.colorScheme.outline, width: c == _selectedColor ? 3 : 1),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.check), tooltip: 'Save note', onPressed: _save),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  hintText: 'Add tags (comma separated)...',
                  prefixIcon: Icon(Icons.tag_rounded, size: 18),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Start writing...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
