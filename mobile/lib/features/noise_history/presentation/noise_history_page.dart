import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/database/dao/noise_measurement_dao.dart';
import '../../../core/database/models/noise_measurement.dart';
import '../../noise_diary/data/diary_sound_label.dart';
import '../../noise_diary/data/diary_export.dart';
import '../data/history_export.dart';
import '../data/noise_history.dart';
import '../../../services/sound_analysis/acoustic_phase.dart';
import '../../../services/sound_analysis/source_phase_upload.dart';

class NoiseHistoryPage extends StatefulWidget {
  const NoiseHistoryPage(
      {super.key, this.collector, this.loadMeasurements, this.saveExport, this.phaseUploads});
  final SourcePhaseUploadService? phaseUploads;
  final SoundHistoryCollector? collector;
  final Future<List<NoiseMeasurement>> Function()? loadMeasurements;
  final Future<bool> Function(String document)? saveExport;

  @override
  State<NoiseHistoryPage> createState() => _NoiseHistoryPageState();
}

class _NoiseHistoryPageState extends State<NoiseHistoryPage> {
  late final SoundHistoryCollector collector =
      widget.collector ?? GetIt.instance<SoundHistoryCollector>();
  late final SourcePhaseUploadService? phaseUploads = widget.phaseUploads ??
      (GetIt.instance.isRegistered<SourcePhaseUploadService>()
          ? GetIt.instance<SourcePhaseUploadService>() : null);
  List<SourceHistoryEntry>? hints;
  List<NoiseMeasurement>? minutes;
  bool loading = true;
  bool failed = false;
  bool changing = false;
  double threshold = 55;
  int maxPauseMinutes = 5;
  int days = 1; // 0 means all stored data.
  int levelLimit = 30;
  int sourceLimit = 50;
  Timer? timer;
  int generation = 0;
  DateTime? windowStart, windowEnd;

  @override
  void initState() {
    super.initState();
    collector.addListener(_collectorChanged);
    phaseUploads?.addListener(_collectorChanged);
    _load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    timer?.cancel();
    collector.removeListener(_collectorChanged);
    phaseUploads?.removeListener(_collectorChanged);
    super.dispose();
  }

  void _collectorChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final request = ++generation;
    try {
      await collector.flush();
      final now = DateTime.now();
      final since = days == 0
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : now.subtract(Duration(days: days));
      final allHints = await collector.store.list();
      final allMinutes = await (widget.loadMeasurements?.call() ??
          NoiseMeasurementDao().getByTimeRange(
            startTimestamp: since.millisecondsSinceEpoch ~/ 1000,
            endTimestamp: now.millisecondsSinceEpoch ~/ 1000,
          ));
      if (!mounted || request != generation) return;
      setState(() {
        hints = allHints
            .where((e) => e.end.isAfter(since) && e.start.isBefore(now))
            .map((e) => SourceHistoryEntry(
                id: e.id,
                category: e.category,
                start: e.start.isBefore(since) ? since : e.start,
                end: e.end.isAfter(now) ? now : e.end,
                confidence: e.confidence,
                isCoverage: e.isCoverage))
            .toList();
        minutes = allMinutes;
        windowStart = since;
        windowEnd = now;
        failed = false;
        loading = false;
      });
    } catch (_) {
      if (mounted && request == generation)
        setState(() {
          failed = true;
          loading = false;
        });
    }
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => changing = true);
    try {
      if (!value) await phaseUploads?.setEnabled(false);
      await collector.setEnabled(value);
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Die Einstellung konnte nicht gespeichert werden.')));
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  Future<void> _changePhaseUpload(bool value, {bool delete = false}) async {
    final service = phaseUploads;
    if (service == null) return;
    final destination = service.transport.baseUrl;
    if (value || delete) {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: Text(delete ? 'Übertragene Phasen löschen?' : 'Private Phasen übertragen?'),
        content: Text(delete
            ? 'Alle hier bekannten Phasen für $destination werden dort gelöscht. Der Upload wird ausgeschaltet. Offline bleibt der Löschauftrag gespeichert; lokale Historie und Tagebuch bleiben erhalten.'
            : 'Neue Geräuscharten, Zeitabschnitte und Analyseabdeckung werden an $destination übertragen, ohne Audio, Transkript oder Standort. Sie bleiben auch bei öffentlichen Sensoren privat, sind für den berechtigten Zugriff und den Serverbetreiber lesbar. Bisherige Historie wird nicht nachträglich versendet. Ausstehende Übertragungen für diesen Server werden fortgesetzt. Ausschalten pausiert die Übertragung, löscht aber keine Serverdaten.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(delete ? 'Löschauftrag speichern' : 'Aktivieren'))],
      ));
      if (confirmed != true || !mounted) return;
      if (service.transport.baseUrl != destination) return;
    }
    setState(() => changing = true);
    try {
      if (delete) { await service.deleteRemotePhases(); }
      else { await service.setEnabled(value); }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Die Änderung konnte nicht gespeichert werden.')));
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Geräuschhinweise löschen?'),
              content: const Text(
                  'Alle gespeicherten Modellhinweise werden von diesem Gerät gelöscht. Persönliche Tagebucheinträge und die separat gespeicherten Minutenpegel bleiben erhalten.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Abbrechen')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Hinweise löschen'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => changing = true);
    try {
      await collector.clear();
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Die Hinweise konnten nicht gelöscht werden.')));
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  Future<void> _export() async {
    setState(() => changing = true);
    try {
      final exporter = DiaryExporter();
      await exporter.cleanStaleTemporaryFiles();
      await _load();
      if (!mounted || failed || windowStart == null || windowEnd == null)
        return;
      // Freeze the content shown for confirmation. No plaintext file is made
      // until the user explicitly chooses to save this snapshot.
      final exportStart = windowStart!, exportEnd = windowEnd!;
      final document = historyExportJson(
          minutes: minutes!,
          hints: hints!,
          start: exportStart,
          end: exportEnd,
          comparisonLine: threshold,
          maxPauseMinutes: maxPauseMinutes);
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Privaten Verlauf exportieren?'),
                content: SingleChildScrollView(
                    child: Text(
                        '${_date(exportStart)} – ${_date(exportEnd)}\n\n'
                        'Die JSON-Datei ist unverschlüsselt. Sie enthält Minutenwerte, '
                        'Episoden und ungeprüfte Modellhinweise des ausgewählten Zeitraums. '
                        'Keine Tonaufnahmen, Tagebuchtexte, Standorte oder Gerätekennungen. '
                        'Wähle einen privaten Speicherort; es erfolgt kein automatischer Upload.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Abbrechen')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Speicherort wählen')),
                ],
              ));
      if (confirmed != true || !mounted) return;
      final saved = await (widget.saveExport?.call(document) ??
          exporter.saveHistory(document));
      if (mounted && saved)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Privater Verlauf exportiert.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Export fehlgeschlagen. Die gespeicherte Historie bleibt erhalten.')));
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}. ${two(local.hour)}:${two(local.minute)}';
  }

  String _duration(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes} Min. ${d.inSeconds % 60} Sek.';
    return '${d.inSeconds} Sek.';
  }

  String _preciseDate(int milliseconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    return '${_date(value)}:${value.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sourceBlocks = groupSourceHistory(hints ?? []);
    final phases = sourcePhases(hints ?? []);
    final levelBlocks = groupLevelHistory(minutes ?? [],
        threshold: threshold, maxPauseMinutes: maxPauseMinutes)
      ..sort((a, b) => b.duration.compareTo(a.duration));
    final longest = levelBlocks.isEmpty
        ? null
        : levelBlocks.reduce((a, b) => a.duration >= b.duration ? a : b);
    return Scaffold(
      appBar: AppBar(title: const Text('Geräuschverlauf'), actions: [
        IconButton(
            onPressed: changing || loading || failed ? null : _export,
            tooltip: 'Verlauf exportieren',
            icon: const Icon(Icons.file_download_outlined)),
        IconButton(
            onPressed: _load,
            tooltip: 'Aktualisieren',
            icon: const Icon(Icons.refresh)),
        IconButton(
            onPressed: changing ? null : _clear,
            tooltip: 'Geräuschhinweise löschen',
            icon: const Icon(Icons.delete_outline)),
      ]),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Geräuschhinweise speichern'),
                              subtitle: Text(collector.enabled
                                  ? 'Aktiv · nur auf diesem Gerät'
                                  : 'Aus · keine neuen Hinweise speichern'),
                              value: collector.enabled,
                              onChanged: changing ? null : _setEnabled),
                          const Text(
                              'Lokal verschlüsselt, ohne Tondateien oder Transkripte. Ereignis-Uploads sind separat.'),
                          const ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text('Speicherung und Datenschutz'),
                            children: [
                              Text(
                                  'Die Historie bleibt lokal verschlüsselt. Nur bei gesondert aktiviertem Phasenupload werden neue Phasen übertragen. Lokal löschen entfernt keine Serverdaten. Ein bewusst gespeicherter Export ist unverschlüsselt. Ereignis-Uploads können ebenfalls Geräuschhinweise enthalten. Minutenpegel werden separat gespeichert.')
                            ],
                          ),
                          if (collector.error != null)
                            const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                    'Die Historie konnte zuletzt nicht gespeichert werden. Prüfe den Gerätespeicher.')),
                        ]))),
            if (phaseUploads != null) Card(child: Padding(
              padding: const EdgeInsets.all(12), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SwitchListTile(contentPadding: EdgeInsets.zero,
                    title: const Text('Private Geräuschphasen übertragen'),
                    subtitle: const Text('Nur neue Phasen · ohne Audio · getrennt von Pegelereignissen'),
                    value: phaseUploads!.enabled,
                    onChanged: changing || !collector.enabled ? null : _changePhaseUpload),
                  Text('${phaseUploads!.acknowledgedCount} aktuelle Stände bestätigt · ${phaseUploads!.pendingCount} ausstehend'),
                  if (phaseUploads!.enabled && !phaseUploads!.destinationMatches)
                    const Text('Backend gewechselt: alte Phasen bleiben an ihren bisherigen Server gebunden. Für neue Phasen die Auswahl aus- und wieder einschalten.'),
                  if (phaseUploads!.error != null)
                    const Text('Die letzte Speicherung oder Übertragung ist fehlgeschlagen. Noch nicht bestätigte Stände bleiben ausstehend.'),
                  TextButton(onPressed: changing ? null : () => _changePhaseUpload(false, delete: true),
                    child: const Text('Übertragene Phasen löschen')),
                ]))),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: days,
              decoration: const InputDecoration(labelText: 'Zeitraum'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Letzte 24 Stunden')),
                DropdownMenuItem(value: 7, child: Text('Letzte 7 Tage')),
                DropdownMenuItem(
                    value: 0, child: Text('Gesamter gespeicherter Zeitraum')),
              ],
              onChanged: (value) {
                setState(() => days = value ?? 1);
                _load();
              },
            ),
            const SizedBox(height: 8),
            const Text(
                'Mögliche Geräuschquellen sind ungeprüfte Modellhinweise. Pegel sind ohne Referenzkalibrierung nur Schätzungen; eine Ursache oder Belästigung ist damit nicht bewiesen.'),
            if (loading)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()))
            else if (failed)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'Verlauf konnte nicht geladen werden. Bereits gespeicherte Daten bleiben erhalten.'))
            else ...[
              const SizedBox(height: 20),
              Text('Zusammenhängende Geräuschphasen',
                  style: Theme.of(context).textTheme.titleLarge),
              const Text('Nach Geräuschart statt Pegelschwelle verbunden. '
                  'Kurze Unterbrechungen bleiben sichtbar; andere Geräusche dürfen gleichzeitig auftreten. '
                  'Ein Modellhinweis beweist weder eine Unterhaltung noch eine bestimmte Ursache.'),
              if (phases.isEmpty)
                Text((hints ?? []).any((e) => e.isCoverage)
                    ? 'Noch keine ausreichend belegten Quellenphasen in diesem Zeitraum.'
                    : 'Für ältere Daten fehlt die dokumentierte Analyseabdeckung. '
                        'Daraus werden keine lückenlosen Quellenphasen nachträglich angenommen.'),
              ...phases.take(sourceLimit).map((phase) {
                final start = DateTime.fromMillisecondsSinceEpoch(phase.start,
                    isUtc: true);
                final end =
                    DateTime.fromMillisecondsSinceEpoch(phase.end, isUtc: true);
                final nearby = unambiguousMinutes(minutes ?? [])
                    .where((m) =>
                        m.leqDb.isFinite &&
                        (m.samplesCount ?? 0) > 0 &&
                        m.timestamp * 1000 >= phase.start &&
                        (m.timestamp + 60) * 1000 <= phase.end)
                    .toList();
                final level = nearby.isEmpty ? null : LevelHistoryBlock(nearby);
                return Card(
                    child: ExpansionTile(
                  title: Text(
                      '${acousticFamilyLabel(phase.family)} · Modellhinweis'),
                  subtitle: Text('${_date(start)} – ${_date(end)} · '
                      '${_duration(Duration(milliseconds: phase.duration))}\n'
                      'Aktiv ${_duration(Duration(milliseconds: phase.activeMs))} · '
                      'dazwischen ${_duration(Duration(milliseconds: phase.pauseMs))} ohne passenden Quellenhinweis'),
                  childrenPadding: const EdgeInsets.all(12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level == null
                        ? 'Keine vollständige Pegelminute in dieser Phase.'
                        : '${nearby.length} vollständige Minuten der gesamten Umgebung: '
                            'Mittel ${level.averageMinute.toStringAsFixed(1)} · '
                            'höchste Minute ${level.highestMinute.toStringAsFixed(1)} (ungeeichte Schätzwerte).'),
                    const Text('Pausen sind keine nachgewiesene Stille. '
                        'Die Analyseabdeckung ist dokumentiert; Quellenhinweise bleiben ungeprüft.'),
                    Text(switch (phase.endReason) {
                      'inference_gap' =>
                        'Getrennt durch eine Lücke in der Analyse.',
                      'pause_limit' =>
                        'Getrennt durch eine längere Phase ohne diesen Quellenhinweis.',
                      'sparse_activity' =>
                        'Getrennt, weil die Hinweise zu vereinzelt auftreten.',
                      _ =>
                        'Bis zum letzten belegten Hinweis; eine Fortsetzung ist unbekannt.',
                    }),
                    ExpansionTile(
                      title: Text(
                          '${phase.activity.length} kurze Aktivitätsabschnitte'),
                      children: [
                        ...phase.activity.take(100).map((part) => Text(
                            '${_preciseDate(part.start)} – ${_preciseDate(part.end)}')),
                        if (phase.activity.length > 100)
                          const Text(
                              'Weitere Aktivitätsabschnitte sind im Export enthalten.'),
                      ],
                    ),
                  ],
                ));
              }),
              if (phases.length > sourceLimit)
                TextButton(
                    onPressed: () => setState(() => sourceLimit += 50),
                    child: const Text('Weitere Geräuschphasen anzeigen')),
              const SizedBox(height: 20),
              Text('Pegelabschnitte über der Vergleichslinie',
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                  'Vergleichslinie ${threshold.round()} · frei wählbar, kein Grenzwert'),
              Slider(
                  value: threshold,
                  min: 10,
                  max: 120,
                  divisions: 110,
                  label: '${threshold.round()}',
                  onChanged: (v) => setState(() => threshold = v)),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: maxPauseMinutes,
                decoration:
                    const InputDecoration(labelText: 'Kurze Pausen verbinden'),
                items: [0, 1, 2, 3, 5, 10]
                    .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value == 0
                            ? 'Ohne Pausen'
                            : 'Bis zu $value Minuten')))
                    .toList(),
                onChanged: (value) =>
                    setState(() => maxPauseMinutes = value ?? 5),
              ),
              const SizedBox(height: 12),
              Text(longest == null
                  ? 'Kein Abschnitt über dieser Linie.'
                  : 'Längste Episode: ${_date(longest.start)} – ${_date(longest.end)} · ${_duration(longest.duration)}'),
              const Text(
                  'Kurze gemessene Phasen unter der Linie bleiben Teil der Episode. Längere Pausen sowie fehlende oder doppelte Minuten trennen sie. Nach Dauer sortiert. Minutenwerte belegen keine lückenlose Aufnahme und die Gruppierung keine gemeinsame Ursache.'),
              ...levelBlocks.take(levelLimit).map((block) {
                final sourceEntries = overlappingSources(block, hints ?? []);
                final coverage = sourceCoverage(block, sourceEntries);
                final possible = sourceEntries
                    .map((h) => diarySoundLabel(h.category))
                    .toSet();
                return Card(
                    child: ExpansionTile(
                  title: Text(
                      '${_date(block.start)} – ${_date(block.end)} · ${_duration(block.duration)}'),
                  subtitle: Text(
                      '${block.activeMinutes} Min. über der Linie · ${block.pauseMinutes} Min. in ${block.pauseCount} kurzen Pausen\n'
                      'Mittel ${block.averageMinute.toStringAsFixed(1)} · höchste Minute ${block.highestMinute.toStringAsFixed(1)} (ungeeichte Schätzwerte)\n'
                      '${possible.isEmpty ? 'Für diesen Zeitraum sind keine Quellenhinweise gespeichert.' : 'Zeitgleiche Modellhinweise: ${possible.join(', ')} (ungeprüft)'}'),
                  childrenPadding: const EdgeInsets.all(12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Quellenhinweise decken ${_duration(coverage)} von ${_duration(block.duration)} ab. Übrige Zeit: Quelle nicht erfasst oder nicht sicher erkannt.'),
                    ...sourceEntries.map((hint) => Text(
                        '${_date(hint.start.isBefore(block.start) ? block.start : hint.start)} – ${_date(hint.end.isAfter(block.end) ? block.end : hint.end)} · ${diarySoundLabel(hint.category)} (Modellhinweis)')),
                  ],
                ));
              }),
              if (levelBlocks.length > levelLimit)
                TextButton(
                  onPressed: () => setState(() => levelLimit += 30),
                  child: Text(
                      '${levelBlocks.length - levelLimit} weitere Pegelabschnitte anzeigen'),
                ),
              const SizedBox(height: 20),
              Text('Erkannte Geräuscharten',
                  style: Theme.of(context).textTheme.titleLarge),
              const Text(
                  'Gleiche Modellhinweise mit Pausen bis zu einer Minute werden gruppiert. Der Zeitraum enthält mögliche Pausen; die erkannte Dauer zählt nur die Modellabschnitte.'),
              if (sourceBlocks.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                        'Keine gespeicherten Modellhinweise in diesem Zeitraum.')),
              ...sourceBlocks.take(sourceLimit).map((block) {
                final nearby = overlappingMinutes(block, minutes ?? []);
                final peak = nearby.isEmpty
                    ? null
                    : nearby
                        .map((m) => m.leqDb)
                        .reduce((a, b) => a > b ? a : b);
                return Card(
                    child: ListTile(
                  title: Text('${diarySoundLabel(block.category)} · ungeprüft'),
                  subtitle: Text(
                      '${_date(block.start)} – ${_date(block.end)} · Zeitraum ${_duration(block.span)}\nErkannt ${_duration(block.detected)}${block.gaps > 0 ? ' · ${block.gaps} Pausen' : ''}\n${peak == null ? 'Kein Minutenpegel verfügbar' : 'Höchster zeitgleicher Minutenwert ${peak.toStringAsFixed(1)} (gesamte Umgebung)'}'),
                  isThreeLine: true,
                ));
              }),
              if (sourceBlocks.length > sourceLimit)
                TextButton(
                  onPressed: () => setState(() => sourceLimit += 50),
                  child: Text(
                      '${sourceBlocks.length - sourceLimit} weitere Geräuschabschnitte anzeigen'),
                ),
            ],
          ])),
    );
  }
}
