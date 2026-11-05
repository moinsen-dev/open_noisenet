import 'package:flutter/material.dart';

import '../data/diary_export.dart';
import '../data/diary_repository.dart';
import '../data/diary_sound_label.dart';

class NoiseDiaryPage extends StatefulWidget {
  const NoiseDiaryPage({super.key, this.repository, this.initialSoundHint});
  final DiaryRepository? repository;
  final DiarySoundHint? initialSoundHint;

  @override
  State<NoiseDiaryPage> createState() => _NoiseDiaryPageState();
}

class _NoiseDiaryPageState extends State<NoiseDiaryPage> {
  late final DiaryRepository _repository =
      widget.repository ?? LocalDiaryRepository();
  List<DiaryEntry>? _entries;
  bool _failed = false;
  final _exporter = DiaryExporter();
  bool _exporting = false;
  bool _exportCleanupPending = true;
  bool _exportCleanupFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _cleanExportFiles();
    final hint = widget.initialSoundHint;
    if (hint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _edit(null, hint);
      });
    }
  }

  Future<void> _cleanExportFiles() async {
    try {
      await _exporter.cleanStaleTemporaryFiles();
      if (mounted)
        setState(() {
          _exportCleanupPending = false;
          _exportCleanupFailed = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _exportCleanupPending = false;
          _exportCleanupFailed = true;
        });
    }
  }

  Future<void> _load() async {
    try {
      final entries = await _repository.list();
      if (mounted)
        setState(() {
          _entries = entries;
          _failed = false;
        });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _edit([DiaryEntry? entry, DiarySoundHint? hint]) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _DiaryEntryEditor(
          repository: _repository, entry: entry, initialSoundHint: hint),
    ));
    if (changed == true) await _load();
  }

  Future<void> _export() async {
    if (_exporting || _entries == null || _entries!.isEmpty) return;
    final entries = List<DiaryEntry>.of(_entries!);
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Export prüfen'),
              content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${entries.length} Einträge als CSV. Die Exportdatei ist unverschlüsselt und enthält deine Beobachtungen sowie übernommene App-Hinweise. Wähle den Speicherort bewusst.'),
                        const SizedBox(height: 12),
                        Flexible(
                            child: SingleChildScrollView(
                                child: SelectableText(diaryEntriesCsv(entries),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall))),
                      ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Abbrechen')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Speicherort wählen'))
              ],
            ));
    if (accepted != true || !mounted) return;
    setState(() => _exporting = true);
    try {
      final saved = await _exporter.save(entries);
      if (mounted && saved)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Export gespeichert. Die Datei liegt am gewählten Speicherort.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Der Export konnte nicht abgeschlossen werden. Bitte prüfe den Speicherort.')));
    } finally {
      if (mounted) setState(() => _exporting = false);
      await _cleanExportFiles();
    }
  }

  Future<void> _delete(DiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Eintrag löschen?'),
                content:
                    const Text('Der Eintrag wird von diesem Gerät gelöscht.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Abbrechen')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Löschen'))
                ]));
    if (confirmed != true) return;
    try {
      await _repository.delete(entry.id);
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Löschen fehlgeschlagen. Bitte erneut versuchen.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mein Lärmtagebuch'), actions: [
        IconButton(
            tooltip: 'Tagebuch exportieren',
            onPressed: _exporting ||
                    _exportCleanupPending ||
                    _exportCleanupFailed ||
                    _entries == null ||
                    _entries!.isEmpty
                ? null
                : _export,
            icon: const Icon(Icons.ios_share)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Eintrag')),
      body: _failed
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Das Tagebuch konnte nicht geladen werden.'),
              TextButton(
                  onPressed: _load, child: const Text('Erneut versuchen'))
            ]))
          : _entries == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  children: [
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(18)),
                          child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Deine Beobachtungen',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                                SizedBox(height: 6),
                                Text(
                                    'Einträge werden auf diesem Gerät verschlüsselt gespeichert. Der Schlüssel ist gerätegebunden; sichere wichtige Einträge selbst per Export. Frühere Gerätesicherungen können unverschlüsselte Kopien enthalten.'),
                              ])),
                      const SizedBox(height: 24),
                      if (_exportCleanupFailed)
                        Card(
                            child: ListTile(
                          title: const Text(
                              'Temporäre Exportdatei konnte nicht bereinigt werden.'),
                          subtitle: const Text(
                              'Der Export ist bis zur Bereinigung gesperrt.'),
                          trailing: TextButton(
                              onPressed: _cleanExportFiles,
                              child: const Text('Erneut versuchen')),
                        )),
                      Text('Verlauf',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      if (_entries!.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                                'Noch keine Einträge. Halte fest, was du selbst beobachtet hast.'))
                      else
                        ..._entries!.map((entry) => Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                title: Text(entry.description),
                                subtitle: Text(
                                    '${_formatDateTime(entry.startedAt)}${entry.endedAt == null ? ' · Ende unbekannt' : ' – ${_formatDateTime(entry.endedAt!)}'}${entry.impact.isEmpty ? '' : '\n${entry.impact}'}\nEigene Beobachtung${entry.soundHint == null ? '' : '\nApp-Vorschlag: ${diarySoundLabel(entry.soundHint!.category)} (ungeprüft)'}'),
                                isThreeLine: true,
                                onTap: () => _edit(entry),
                                trailing: IconButton(
                                    tooltip: 'Eintrag löschen',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(entry)),
                              ),
                            )),
                      const SizedBox(height: 12),
                      Text(
                          'Das Tagebuch ist eine persönliche Dokumentation. Es misst keinen Schallpegel und bestimmt keine Ursache.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
    );
  }
}

String _formatDateTime(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class _DiaryEntryEditor extends StatefulWidget {
  const _DiaryEntryEditor(
      {required this.repository, this.entry, this.initialSoundHint});
  final DiaryRepository repository;
  final DiaryEntry? entry;
  final DiarySoundHint? initialSoundHint;
  @override
  State<_DiaryEntryEditor> createState() => _DiaryEntryEditorState();
}

class _DiaryEntryEditorState extends State<_DiaryEntryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _impact;
  late DateTime _start;
  DateTime? _end;
  bool _saving = false;
  String? _error;
  DiarySoundHint? _soundHint;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.entry?.description);
    _impact = TextEditingController(text: widget.entry?.impact);
    final now = DateTime.now();
    _soundHint = widget.entry?.soundHint ?? widget.initialSoundHint;
    _start = widget.entry?.startedAt ??
        widget.initialSoundHint?.start.toLocal() ??
        DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _end = widget.entry == null
        ? widget.initialSoundHint?.end.toLocal()
        : widget.entry?.endedAt;
  }

  @override
  void dispose() {
    _description.dispose();
    _impact.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isEnd) async {
    final initial = isEnd ? (_end ?? _start) : _start;
    final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    final value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isEnd) {
        _end = value;
      } else {
        _start = value;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_end != null && _end!.isBefore(_start)) {
      setState(() => _error = 'Das Ende darf nicht vor dem Beginn liegen.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(DiaryEntry(
          id: widget.entry?.id ?? newDiaryEntryId(),
          startedAt: _start,
          endedAt: _end,
          description: _description.text.trim(),
          impact: _impact.text.trim(),
          soundHint: _soundHint));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error =
              'Speichern fehlgeschlagen. Dein Text bleibt erhalten; bitte erneut versuchen.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.entry == null
                ? 'Beobachtung hinzufügen'
                : 'Eintrag bearbeiten')),
        body: Form(
            key: _formKey,
            child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                      'Beschreibe, was du selbst wahrgenommen hast. Du musst keine Quelle oder Person nennen.'),
                  if (_soundHint != null)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'App-Vorschlag: ${diarySoundLabel(_soundHint!.category)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      'Ungeprüfter Hinweis · ${_formatDateTime(_soundHint!.start.toLocal())} – ${_formatDateTime(_soundHint!.end.toLocal())}. Die Quelle ist nicht bewiesen.'),
                                  TextButton(
                                      onPressed: () =>
                                          setState(() => _soundHint = null),
                                      child: const Text('Vorschlag entfernen')),
                                ]))),
                  const SizedBox(height: 20),
                  TextFormField(
                      controller: _description,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Was hast du wahrgenommen?',
                          border: OutlineInputBorder()),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Bitte eine Beobachtung eingeben.'
                              : null),
                  const SizedBox(height: 12),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Beginn'),
                      subtitle: Text(_formatDateTime(_start)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: () => _pickDateTime(false)),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ende · optional'),
                      subtitle: Text(
                          _end == null ? 'Unbekannt' : _formatDateTime(_end!)),
                      trailing: _end == null
                          ? const Icon(Icons.add)
                          : IconButton(
                              tooltip: 'Ende entfernen',
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _end = null)),
                      onTap: () => _pickDateTime(true)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _impact,
                      maxLength: 500,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText:
                              'Wie hat es dich beeinträchtigt? · optional',
                          border: OutlineInputBorder())),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving
                          ? 'Wird gespeichert …'
                          : 'Eintrag speichern')),
                ])),
      );
}
