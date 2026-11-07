# Deutsche Storebilder mit Geräuschphasen als Einstieg

Udi hat am 07.11.2026 diese Richtung zur Umsetzung ausgewählt. Fünf Bilder und
deutsche Metadaten für Google Play, keine neue App-Version und kein ASO-Experiment.
Der konkrete Providerstand steht in [current-status.md](../../../current-status.md).

## Fertige Dateien

- [Store-Vorschau](google-play/de-DE/preview.html), mit anklickbaren Bildern und Beschreibung.
- [Übersicht der Bildfolge](google-play/de-DE/overview.jpg).
- [01 · Geräuschphasen](google-play/de-DE/01-phases.jpg).
- [02 · Dauer und Pausen](google-play/de-DE/02-duration.jpg).
- [03 · Mögliche Quellen](google-play/de-DE/03-sources.jpg).
- [04 · Persönliches Tagebuch](google-play/de-DE/04-diary.jpg).
- [05 · Export](google-play/de-DE/05-export.jpg).
- [Metadaten](google-play/de-DE/metadata.json), [Langbeschreibung](google-play/de-DE/description.txt).

Alle fünf Dateien sind JPEG mit 1080 × 1920 Pixeln, ohne Transparenz, je weniger
als 200 KB. Der Schriftbereich außerhalb der App liegt unter einem Fünftel der
Bildhöhe. Die Rohansichten sind unter `raw/android/` unverändert erhalten.
HTML-Dateien neben den JPEGs sind die reproduzierbaren Layoutquellen.

## Herkunft und Grenzen

Die Screens stammen aus dem **Android-Release 0.1.0 (6)** auf einem eigenen
Android-15-Emulator mit 16-KB-Seiten. Für die lokale Installation wurde die bereits
geprüfte Universal-APK mit dem lokalen Android-Debug-Schlüssel neu signiert. Alle
414 ZIP-Einträge außerhalb der Signaturmetadaten stimmen bytegenau mit dem
Original überein. `DEBUGGABLE` ist nicht gesetzt. Das ist eine Release-Ausführung,
kein neuer Installationsnachweis über Google Play. Prüfsummen in
[provenance.json](provenance.json).

Ein separater, nur auf Android-Emulatoren ausführbarer Debug-Datenlader schreibt
synthetische Quellenintervalle, Analyseabdeckung, Minutenwerte und zwei
Tagebucheinträge über die normalen Datenzugriffe. Er verweigert vorhandene
Messungen/Einträge und physische Geräte. Vor den Screenshots wurde er durch die
Release-APK ersetzt. Die normale App entschlüsselt und gruppiert die Daten selbst.
Kein UI-Nachbau, keine retuschierten Texte oder erfundenen Bedienelemente.

Die sichtbaren 19 Minuten Straßenverkehr enthalten 18 Minuten Aktivität und drei
20-Sekunden-Pausen; Werkzeuggeräusche 18 Minuten mit zwei 15-Sekunden-Pausen;
Sprachaktivität acht Minuten mit zwei 15-Sekunden-Pausen. Das sind bewusst
konstruierte Beispiele, kein Modellgenauigkeits- oder Belästigungsnachweis.
Androids Demonstrationsmodus setzt die Statusuhr auf 09:41. Mikrofonzugriff blieb
aus; keine realen Aufnahmen oder Pixel-Daten wurden verwendet. Upload war aus.

Der Export wurde nach dem fünften Screenshot tatsächlich über Androids
Speicherortdialog gespeichert. Die CSV enthält beide Beispiele und getrennte
Spalten für eigene Beobachtung, Auswirkung und ungeprüfte App-Vorschläge. Der
native Picker ist nicht das fünfte Motiv; das Bild zeigt die echte Exportprüfung
direkt davor.

## Wiederholbare Produktion

1. Eigenen frischen Emulator anlegen; kein physisches Gerät wählen. Datum und
   Zeitzone prüfen. `mobile/tool/store_seed_main.dart` verlangt `ONN_ASO_FIXTURE=true`,
   Debugmodus, `ro.kernel.qemu=1` und eine Uhrzeit nach 09:15. Es löscht keine Daten.
2. Loader mit dem normalen Android-Debug-Schlüssel bauen und installieren. Auf
   `ONN_ASO_SEED_READY` warten. Danach die unveränderte Release-APK mit demselben
   **lokalen QA-Schlüssel** signieren und per Update installieren. Keines dieser
   Pakete in einen Store hochladen. Den offiziellen Upload-Schlüssel nicht für
   die Fixture verwenden.
3. Releaseoberfläche über die normalen Tabs bedienen. Verlauf zum Abschnitt
   „Zusammenhängende Geräuschphasen“ scrollen, Straßenverkehr samt vier
   Aktivitätsabschnitten öffnen, dann „Erkannte Geräuscharten“, Tagebuch und
   Exportprüfung aufnehmen. Alle Rohbilder mit `adb exec-out screencap -p` erzeugen.
4. `python3 scripts/build-store-listing.py` setzt die Rohbilder unverändert in die
   Layouts und erzeugt Metadaten. Die fünf HTML-Canvases bei 1080 × 1920 im Browser
   als JPEG rendern, anschließend Bildmaße, Reihenfolge und Inhalt prüfen. Die
   fertigen JPEGs sind gespeichert; der vollständige Ordner lässt sich danach
   offline im Browser öffnen.
5. In Play nur **German – de-DE** bearbeiten. Fünf Dateien aufsteigend ordnen;
   parallele Uploads kamen in anderer Reihenfolge an. Als Entwurf speichern und
   erneut öffnen. Einreichen/Veröffentlichen und A/B-Test sind getrennte Schritte.

Das Icon und die Vorstellungsgrafik gehören nicht zu dieser Änderung. Die
englische Storefassung bleibt ein separater Lokalisierungsschritt. Die fünf
Android-Ansichten sind keine iOS-Screenshots.

## Geprüft

- Fixture mit Dart analysiert, Debug-APK gebaut, sicher auf eigenem Emulator ausgeführt.
- Original-Release-Code und -Assets bytegenau gegen die QA-APK abgeglichen.
- Alle fünf Ansichten und gestalteten Bilder visuell geprüft; Bildmaße/Dateigröße geprüft.
- Synthetischen CSV-Export über die echte Systemauswahl gespeichert und inhaltlich geprüft.
- Keine Produkt-Codeänderung und kein neuer Release erforderlich. Quellenhinweise und
  Tagebucheinträge sind verschlüsselt; separat gespeicherte Minutenpegel werden im
  Storetext ausdrücklich davon unterschieden.
