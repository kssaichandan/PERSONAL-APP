import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../database.dart';

String plainText(String deltaJson) {
  try {
    final delta = jsonDecode(deltaJson);
    return (delta as List).map((op) => op['insert'] ?? '').join().trim();
  } catch (_) {
    return deltaJson;
  }
}

class Note {
  final int? id;
  final String title;
  final String content;
  final int color; // ARGB value
  final bool pinned;
  final String tags; // Comma-separated
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

  Note copyWith({
    String? title,
    String? content,
    int? color,
    bool? pinned,
    String? tags,
    DateTime? updatedAt,
  }) => Note(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    color: color ?? this.color,
    pinned: pinned ?? this.pinned,
    tags: tags ?? this.tags,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class NoteRecording {
  final int id;
  final int noteId;
  final String filePath;
  final int durationSeconds;
  final DateTime createdAt;

  NoteRecording({
    required this.id,
    required this.noteId,
    required this.filePath,
    required this.durationSeconds,
    required this.createdAt,
  });

  factory NoteRecording.fromMap(Map<String, dynamic> m) => NoteRecording(
    id: m['id'],
    noteId: m['note_id'],
    filePath: m['file_path'],
    durationSeconds: m['duration_seconds'],
    createdAt: DateTime.parse(m['created_at']),
  );
}

class NotesProvider extends ChangeNotifier {
  List<Note> _notes = [];
  List<Note> _filtered = [];
  final Map<int, List<NoteRecording>> _recordingsByNoteId = {};
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
          if (tag.trim().isNotEmpty) {
            tagsSet.add(tag.trim());
          }
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
        plainText(n.content).toLowerCase().contains(q.toLowerCase())
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

      final recMaps = await db.query('note_recordings');
      _recordingsByNoteId.clear();
      for (final rec in recMaps) {
        final recording = NoteRecording.fromMap(rec);
        _recordingsByNoteId.putIfAbsent(recording.noteId, () => []).add(recording);
      }
    } catch (e) {
      _error = 'Failed to load notes';
    }
    _loading = false;
    notifyListeners();
  }

  List<NoteRecording> getRecordings(int noteId) {
    return _recordingsByNoteId[noteId] ?? [];
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
      
      // Delete local voice recording files
      final recs = _recordingsByNoteId[id] ?? [];
      for (final rec in recs) {
        try {
          final file = File(rec.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('delete local file failed: $e');
        }
      }

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

  Future<void> saveRecording(int noteId, String filePath, int durationSeconds) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert('note_recordings', {
        'note_id': noteId,
        'file_path': filePath,
        'duration_seconds': durationSeconds,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('saveRecording failed: $e');
    }
    await load();
  }

  Future<void> deleteRecording(int recId, String filePath) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('note_recordings', where: 'id = ?', whereArgs: [recId]);
      
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('deleteRecording failed: $e');
    }
    await load();
  }
}

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Consumer<NotesProvider>(
        builder: (context, provider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: provider.query.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => provider.search(''))
                      : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainer,
                    isDense: true,
                  ),
                  onChanged: provider.search,
                ),
              ),

              // Tags Filter Horizontal Row
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
                          label: Text(tag),
                          selected: isSel,
                          onSelected: (_) => provider.selectTag(tag),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      );
                    },
                  ),
                ),

              // Notes Grid
              Expanded(
                child: _buildGrid(context, provider),
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

  Widget _buildGrid(BuildContext context, NotesProvider provider) {
    final theme = Theme.of(context);
    if (provider.error != null) return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)));
    if (provider.loading) return const Center(child: CircularProgressIndicator());
    if (provider.notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notes_rounded, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(provider.query.isNotEmpty ? 'No matching notes' : 'No notes yet', style: const TextStyle(color: Colors.grey, fontSize: 16)),
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
        final recordings = provider.getRecordings(note.id ?? 0);
        final color = Color(note.color);
        final isDarkNote = color.computeLuminance() < 0.5;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note))),
          child: Card(
            elevation: 1,
            color: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.8),
            ),
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
                      plainText(note.content),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkNote ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (recordings.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.mic, size: 12, color: isDarkNote ? Colors.white70 : Colors.black54),
                            const SizedBox(width: 2),
                            Text('${recordings.length}', style: TextStyle(fontSize: 10, color: isDarkNote ? Colors.white70 : Colors.black54)),
                          ],
                        )
                      else
                        const SizedBox(),
                      Text(
                        DateFormat('MMM d').format(note.updatedAt),
                        style: TextStyle(fontSize: 10, color: isDarkNote ? Colors.white38 : Colors.black38),
                      ),
                    ],
                  )
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
  late QuillController _controller;
  late TextEditingController _titleController;
  late TextEditingController _tagsController;
  late int _selectedColor;
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _tagsController = TextEditingController(text: widget.note?.tags ?? '');
    _selectedColor = widget.note?.color ?? 0xFFFFFFFF;

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
    _tagsController.dispose();
    _controller.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final voiceDir = Directory('${dir.path}/voice_notes');
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${voiceDir.path}/note_rec_$timestamp.m4a';

      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordSeconds++;
        });
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio recording permission is required'))
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
    });

    if (path != null && widget.note?.id != null) {
      await context.read<NotesProvider>().saveRecording(widget.note!.id!, path, _recordSeconds);
    } else if (path != null && widget.note?.id == null) {
      // Note not saved yet, we must save note first
      final noteId = await _saveNoteSilent();
      if (!mounted) return;
      await context.read<NotesProvider>().saveRecording(noteId, path, _recordSeconds);
    }
  }

  Future<int> _saveNoteSilent() async {
    final content = jsonEncode(_controller.document.toDelta().toJson());
    final note = Note(
      id: widget.note?.id,
      title: _titleController.text,
      content: content,
      color: _selectedColor,
      pinned: widget.note?.pinned ?? false,
      tags: _tagsController.text,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (!mounted) return 0;
    final noteId = await context.read<NotesProvider>().save(note);
    return noteId;
  }

  void _save() async {
    await _saveNoteSilent();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<NotesProvider>();
    final recordings = widget.note?.id != null ? provider.getRecordings(widget.note!.id!) : <NoteRecording>[];

    final colorsList = [
      0xFFFFFFFF, // white
      0xFFF28B82, // red
      0xFFFBBC04, // orange
      0xFFFFF475, // yellow
      0xFFCCFF90, // green
      0xFFA7FFEB, // teal
      0xFFCBF0F8, // blue
      0xD7AECFC9, // dark gray/teal
      0xFFD7AEFB, // purple
      0xFFFDCFE8, // pink
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
          IconButton(icon: const Icon(Icons.palette_outlined), onPressed: () {
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
                          border: Border.all(color: Colors.grey.shade400, width: c == _selectedColor ? 3 : 1),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tags Input Row
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
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const Divider(height: 1),

            // Toolbar
            QuillSimpleToolbar(controller: _controller),
            
            // Rich Text Editor View
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: QuillEditor.basic(controller: _controller),
              ),
            ),

            // Voice Memo Record Section
            if (_isRecording)
              Container(
                color: theme.colorScheme.primaryContainer,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mic, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Recording Voice Note...', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        Text(
                          '${(_recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop_circle_rounded, color: Colors.red, size: 36),
                      onPressed: _stopRecording,
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Voice Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.mic_none_rounded),
                      onPressed: _startRecording,
                    ),
                  ],
                ),
              ),

            // Voice Memos List
            if (recordings.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                color: theme.colorScheme.surfaceContainerLowest,
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recordings.length,
                  itemBuilder: (context, i) {
                    final rec = recordings[i];
                    return _AudioPlayerWidget(
                      recording: rec,
                      onDelete: () => provider.deleteRecording(rec.id, rec.filePath),
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

class _AudioPlayerWidget extends StatefulWidget {
  final NoteRecording recording;
  final VoidCallback onDelete;

  const _AudioPlayerWidget({required this.recording, required this.onDelete});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.recording.durationSeconds);
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() {
          _duration = d;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.recording.filePath));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 32),
            onPressed: _togglePlay,
          ),
          Text(
            '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          Expanded(
            child: Slider(
              value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
              onChanged: (val) async {
                await _audioPlayer.seek(Duration(seconds: val.toInt()));
              },
            ),
          ),
          Text(
            '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: widget.onDelete,
          )
        ],
      ),
    );
  }
}
