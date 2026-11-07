import 'package:flutter/material.dart';

import '../../../../services/map_pilot/pilot_consent_controller.dart';

/// Participation is disabled in the actual app until pilot gates are passed.
class MapPilotPreview extends StatefulWidget {
  const MapPilotPreview(
      {super.key,
      required this.controller,
      required this.destination,
      this.available = false});
  final PilotConsentController controller;
  final String destination;
  final bool available;

  @override
  State<MapPilotPreview> createState() => _MapPilotPreviewState();
}

class _MapPilotPreviewState extends State<MapPilotPreview> {
  bool busy = false;
  String? message;

  Future<void> _enable() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.controller.enable(widget.destination);
      message = widget.controller.enabled
          ? 'Freigabe gespeichert.'
          : 'Freigabe konnte nicht bestätigt werden.';
    } catch (_) {
      message =
          'Freigabe nicht bestätigt. Ein eventuell ausstehender Widerruf muss zuerst gesendet werden.';
    }
    if (mounted)
      setState(() {
        busy = false;
      });
  }

  Future<void> _withdraw() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final done = await widget.controller.withdraw();
      message = done
          ? 'Widerruf vom Server bestätigt.'
          : 'Widerruf vorgemerkt; die Serverbestätigung steht noch aus.';
    } catch (_) {
      message =
          'Widerruf nicht bestätigt. Bitte den ursprünglichen Server und das ursprüngliche Konto prüfen.';
    }
    if (mounted)
      setState(() {
        busy = false;
      });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Freiwilliger Kartenpilot'),
        content: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Gebiet: Stadtteil Hamburg-Eimsbüttel. Der gewählte Server erhält dein Konto, den Tag, die Gebietskennung und eine Beitragsklasse. Öffentlich vorgesehen sind nur abgeschlossene Wochen für das gesamte Gebiet mit mindestens fünf bestätigten Teilnehmenden.'),
            const SizedBox(height: 12),
            const Text(
                'Keine Rohaufnahmen, Tagebuchtexte, genauen Standorte oder einzelnen Geräte auf der Karte. Die Teilnahme ist freiwillig; bisherige private Daten werden nicht automatisch übernommen.'),
            const SizedBox(height: 12),
            const Text(
                'Nach einer Veröffentlichung können Kopien durch Dritte möglicherweise nicht zurückgeholt werden. Messwerte sind keine Grenzwert- oder Ursachenbeweise.'),
            const SizedBox(height: 12),
            if (!widget.available)
              const Text(
                  'Der Kartenpilot ist noch nicht freigegeben. Es werden keine Kartenbeiträge gesendet.'),
            if (widget.controller.pendingWithdrawal)
              const Text('Ein Widerruf wartet auf Serverbestätigung.'),
            if (message != null) Text(message!),
          ],
        )),
        actions: [
          if (widget.controller.hasSavedConsentOrWithdrawal)
            TextButton(
                onPressed: busy ? null : _withdraw,
                child: const Text('Widerruf senden')),
          if (widget.available &&
              !widget.controller.hasSavedConsentOrWithdrawal)
            TextButton(
                onPressed: busy ? null : _enable,
                child: const Text('Freiwillig aktivieren')),
          TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Schließen')),
        ],
      );
}
