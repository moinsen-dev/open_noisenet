import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'diary_repository.dart';
import 'diary_sound_label.dart';

/// CSV is deliberately unencrypted; only generate it on an explicit export.
String diaryEntriesCsv(List<DiaryEntry> entries) {
  String cell(String text) {
    // Spreadsheets may execute formulas even in quoted CSV cells.
    final safe = RegExp(r'^[\s]*[=+\-@\t\r]').hasMatch(text) ? "'$text" : text;
    return '"${safe.replaceAll('"', '""')}"';
  }

  final rows = <List<String>>[
    [
      'Beginn (UTC)',
      'Ende (UTC)',
      'Eigene Beobachtung',
      'Eigene Auswirkung',
      'App-Vorschlag (ungeprüft)',
      'Hinweis Beginn (UTC)',
      'Hinweis Ende (UTC)'
    ],
    for (final entry in entries)
      [
        entry.startedAt.toUtc().toIso8601String(),
        entry.endedAt?.toUtc().toIso8601String() ?? '',
        entry.description,
        entry.impact,
        entry.soundHint == null
            ? ''
            : diarySoundLabel(entry.soundHint!.category),
        entry.soundHint?.start.toUtc().toIso8601String() ?? '',
        entry.soundHint?.end.toUtc().toIso8601String() ?? ''
      ],
  ];
  return '${rows.map((row) => row.map(cell).join(',')).join('\r\n')}\r\n';
}

class DiaryExporter {
  static const _prefix = 'OpenNoiseNet-Tagebuch-';
  static final Set<String> _active = {};
  static final RegExp _ownTemporaryFile = RegExp(
      r'^OpenNoiseNet-(Tagebuch-[0-9a-f-]{36}\.csv|Verlauf-[0-9a-f-]{36}\.json)$');

  /// The iOS picker writes a temporary plaintext file before showing its UI.
  /// Clean only our own stale files, never another active export or app data.
  Future<void> cleanStaleTemporaryFiles() async {
    if (!Platform.isIOS) return;
    await cleanTemporaryDirectory(Directory.systemTemp);
  }

  @visibleForTesting
  Future<void> cleanTemporaryDirectory(Directory temp) async {
    await for (final entity in temp.list(followLinks: false)) {
      final name = path.basename(entity.path);
      if (entity is File &&
          _ownTemporaryFile.hasMatch(name) &&
          !_active.contains(name)) {
        await entity.delete();
      }
    }
  }

  Future<bool> save(List<DiaryEntry> entries) => _save(
      '$_prefix${const Uuid().v4()}.csv',
      diaryEntriesCsv(entries),
      'text/csv',
      'Tagebuch exportieren');

  Future<bool> saveHistory(String document) => _save(
      'OpenNoiseNet-Verlauf-${const Uuid().v4()}.json',
      document,
      'application/json',
      'Geräuschverlauf exportieren');

  Future<bool> _save(
      String name, String document, String mime, String title) async {
    _active.add(name);
    try {
      final result = await FilePicker.saveFile(
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(document)),
        mimeType: mime,
        dialogTitle: title,
      );
      return result != null;
    } finally {
      try {
        if (Platform.isIOS) {
          final temporaryFile =
              File(path.join(Directory.systemTemp.path, name));
          if (await temporaryFile.exists()) await temporaryFile.delete();
        }
      } finally {
        _active.remove(name);
      }
    }
  }
}
