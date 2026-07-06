import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../database.dart';

class Note {
  final int? id;
  final String title;
  final String content;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({this.id, required this.title, required this.content, this.pinned = false, required this.createdAt, required this.updatedAt});

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'content': content,
    'pinned': pinned ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'], title: m['title'], content: m['content'],
    pinned: m['pinned'] == 1,
    createdAt: DateTime.parse(m['created_at']),
    updatedAt: DateTime.parse(m['updated_at']),
  );

  Note copyWith({String? title, String? content, bool? pinned, DateTime? updatedAt}) => Note(
    id: id, title: title ?? this.title, content: content ?? this.content,
    pinned: pinned ?? this.pinned, createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
  );
}

class NotesProvider extends ChangeNotifier {
  List<Note> _notes = [];
  List<Note> _filtered = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  List<Note> get notes => _query.isNotEmpty ? _filtered : _notes;
  bool get loading => _loading;
  String? get error => _error;
  String get query => _query;

  NotesProvider() { load(); }

  void search(String q) {
    _query = q;
    if (q.isEmpty) { _filtered = []; }
    else { _filtered = _notes.where((n) => n.title.toLowerCase().contains(q.toLowerCase()) || _plainText(n.content).toLowerCase().contains(q.toLowerCase())).toList(); }
    notifyListeners();
  }

  String _plainText(String deltaJson) {
    try {
      final delta = jsonDecode(deltaJson);
      return (delta as List).map((op) => op['insert'] ?? '').join().trim();
    } catch (_) {
      return deltaJson;
    }
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
        await db.insert('notes', note.toMap()..remove('id'));
      } else {
        await db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
      }
    } catch (e) {
      _error = 'Failed to save note';
      notifyListeners();
      return;
    }
    await load();
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
    await save(note.copyWith(pinned: !note.pinned));
  }
}

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Consumer<NotesProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: provider.query.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => provider.search(''))
                      : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: provider.search,
                ),
              ),
              Expanded(
                child: _buildList(provider),
              ),
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

  Widget _buildList(NotesProvider provider) {
    if (provider.error != null) return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)));
    if (provider.loading) return const Center(child: CircularProgressIndicator());
    if (provider.notes.isEmpty) {
      return Center(child: Text(provider.query.isNotEmpty ? 'No matching notes' : 'No notes yet'));
    }
    return ListView.builder(
      itemCount: provider.notes.length,
      itemBuilder: (context, i) {
        final note = provider.notes[i];
        return Dismissible(
          key: ValueKey(note.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => provider.delete(note.id!),
          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
          child: ListTile(
            title: Text(note.title.isEmpty ? 'Untitled' : note.title, maxLines: 1),
            subtitle: Text(_plainText(note.content), maxLines: 2, overflow: TextOverflow.ellipsis),
            leading: note.pinned ? const Icon(Icons.push_pin) : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note))),
          ),
        );
      },
    );
  }

  String _plainText(String deltaJson) {
    try {
      final delta = jsonDecode(deltaJson);
      return (delta as List).map((op) => op['insert'] ?? '').join().trim();
    } catch (_) {
      return deltaJson;
    }
  }
}

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late QuillController _controller;
  late TextEditingController _titleController;

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
    final content = jsonEncode(_controller.document.toDelta().toJson());
    final note = Note(
      id: widget.note?.id,
      title: _titleController.text,
      content: content,
      pinned: widget.note?.pinned ?? false,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await context.read<NotesProvider>().save(note);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none)),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
          if (widget.note != null)
            PopupMenuButton(itemBuilder: (context) => [
              PopupMenuItem(value: 'pin', child: Text(widget.note!.pinned ? 'Unpin' : 'Pin')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ], onSelected: (v) async {
              final provider = context.read<NotesProvider>();
              if (v == 'delete') {
                await provider.delete(widget.note!.id!);
                if (mounted) Navigator.pop(context);
              } else if (v == 'pin') {
                await provider.togglePin(widget.note!);
                if (mounted) Navigator.pop(context);
              }
            }),
        ],
      ),
      body: Column(
        children: [
          QuillSimpleToolbar(controller: _controller),
          Expanded(child: QuillEditor.basic(controller: _controller)),
        ],
      ),
    );
  }
}
