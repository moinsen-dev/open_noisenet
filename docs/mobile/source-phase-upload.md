# Privater Phasenupload und natürliche Gespräche

Stand: 05.11.2026. Implementiert und lokal integriert. Nicht auf dem laufenden Pixel R2 installiert oder auf dessen Backend migriert. Bestehende schwellenbasierte Ereignisse und öffentliche Karte bleiben unverändert.

## App und Datenschutz

Die neue Wahl **„Private Geräuschphasen übertragen“** ist standardmäßig aus und setzt lokale Historie voraus. Die Bestätigung nennt den konkreten Server, Datenumfang, Lesbarkeit für dessen Betreiber und getrennte Löschung. Nur neue vollständige Analysefenster nach Zustimmung fließen ein. Ältere Historie wird nicht nachträglich übertragen; bereits autorisierte ausstehende Revisionen desselben Servers können wiederholt werden.

YAMNet und der gemeinsame `source_phases_v1`-Kern bilden fortsetzbare Phasen mit stabiler UUID. Alle 30 Sekunden wird ein vollständiger Stand gespeichert; neuere Offline-Stände ersetzen ältere derselben Kennung. Eine zweisekündige Stabilisierung verhindert vorzeitige Startgrenzen während der Modellhysterese. Inferenzlücken und Prozessneustarts trennen die Phasen ausdrücklich. Ein alter offener Stand wird nach Neustart als unterbrochen abgeschlossen. Bis zu 30 Sekunden ungesicherte Schlussdaten können bei Prozessverlust fehlen.

Nutzlast, Zielserver, Gerätebindung, Revision und Bestätigungszustand liegen AES-GCM-verschlüsselt in der bestehenden Diary-Datenbank, Schema 4. Die Migration erhält ältere Einträge. Bei fehlendem Schlüssel wird der Bestand nicht ersetzt. Ein bei Schreibfehlern nur im Speicher vorgemerkter Stand bleibt für Wiederholung erhalten, ist aber nicht gegen Prozessverlust gesichert. Die UI meldet diesen Fehler. Neue Roh-Audioaufnahmen bleiben gesperrt.

Ausschalten pausiert Übertragung und schließt die Erfassung lokal ab, löscht jedoch keine Serverdaten. Backendwechsel leiten keine alten Daten an einen neuen Server weiter. **„Übertragene Phasen löschen“** schaltet den Upload aus und speichert verschlüsselte Löschaufträge für alle lokal bekannten Phasen des aktuell gebundenen Servers. Diese werden auch nach Offline-Zeit wiederholt und erst nach passender Serverantwort aus der Queue entfernt. Lokale Historie und Tagebuch bleiben erhalten. Deren eigene Löschaktion löscht umgekehrt keine Serverdaten. Nach Verlust der lokalen Queue kann diese UI frühere Serverphasen nicht mehr vollständig aufzählen; Geräte-/Kontoverwaltung bleibt eine zusätzliche Verantwortung.

## API-Vertrag

| Operation | Pfad | Berechtigung |
|---|---|---|
| Vollständigen Stand anlegen/fortsetzen | `PUT /api/v1/source-phases/{device_id}/{phase_id}` | `X-Device-Key` |
| Private aktuelle Stände lesen | `GET /api/v1/source-phases/{device_id}?offset=0&limit=50` | Geräteschlüssel oder Gerätebesitzer |
| Inhalt löschen und Wiederholung sperren | `DELETE /api/v1/source-phases/{device_id}/{phase_id}` | `X-Device-Key` |

Payload: UUID, positive Revision, `algorithm=source_phases_v1`, `source_model=yamnet_tflite_4d8b4a53`, Quellenfamilie, Start/Ende, letzter analysierter Zeitpunkt, aktive Millisekunden, Pausenmillisekunden, sortierte vereinigte Aktivitätsintervalle, Zustand und Abschlussgrund. Keine freien Texte, Rohaufnahmen, Transkripte, Koordinaten oder Embeddings. **Keine Pegelzusammenfassung pro Quellenphase:** Minuten und Pegelereignisse bleiben getrennt; ihr Pegel darf nicht einer einzelnen Quelle zugeschrieben werden.

- Gleiche UUID/Revision/Inhalt: wiederholbare Bestätigung. Höhere Revisionen dürfen nach Offline-Zusammenfassung übersprungen werden, müssen aber Identität und bisherige Aktivität erhalten. Veraltete, verkürzte, widersprüchliche Stände: 409. Abgeschlossene Phasen lassen sich nicht wieder öffnen.
- ACK enthält Gerätekennung, Phasenkennung, exakte Revision, SHA-256 der kanonischen JSON-Nutzlast und `acknowledged_by_server`. Erst nach Datenbank-Commit bestätigt das Backend; nur passende Antworten zählen in der App. Verlorene Antworten führen zu identischen Wiederholungen.
- PostgreSQL sperrt die Gerätezeile während Änderungen und serialisiert damit auch gleichzeitige Erstanlage/Löschung. UUID und Gerät sind gemeinsam eindeutig.
- DELETE entfernt Nutzlast und Digest. Eine minimale Löschmarke mit Gerätebindung, UUID, letzter Revision und Verwaltungszeitpunkten bleibt, damit verspätete PUTs mit 410 abgewiesen werden. Auch Löschen vor dem ersten Upload sperrt spätere Wiederholung. Keine physische Speicherlösch- oder Backupgarantie.
- Immer privat, auch bei öffentlichen Sensoren; keine Projektion in Event-/Kartenabfragen. Release-Client verlangt HTTPS und folgt keinen Redirects. Hier ausschließlich Loopback-HTTP geprüft.

Backend-Migration `438d7e8c9f10` auf `94a38b0e8f12`, Tabelle `source_phases`. Upgrade/Downgrade/Upgrade auf eigener temporärer PostgreSQL-16-Datenbank bestanden. Downgrade entfernt die Tabelle und ist kein Verfahren für vorhandene Nutzerdaten.

## Natürliche Gesprächsszenen

Zwei nicht-szenariobasierte Besprechungen aus dem [AMI Meeting Corpus](https://groups.inf.ed.ac.uk/ami/corpus/), ausgewählt über die [offiziellen Downloads](https://groups.inf.ed.ac.uk/ami/download/). AMI Consortium / University of Edinburgh, CC BY 4.0. EN2002b über Headset und Raummikrofon, EN2006a über Raummikrofon; je vier Sprecher mit manuellen Wortzeitmarken. Die beiden Spuren desselben Treffens sind keine unabhängigen Gespräche.

Vor Inferenz festgelegt: jeweils 20 Minuten ab Originalsekunde 60, keine nachträgliche Parameteranpassung. YAMNet SHA-256 `4d8b4a53282dc83ef04e3e7dbc4fbc98082e34e44ed798e16c3a0cdd4c584faf`, 2.498 vollständige 975-ms-Fenster je Spur, Schrittweite 480 ms, keine Stille-Abkürzung. Letzte 465 ms ohne vollständiges Fenster. App-Kategorien und Dart-Zeitkern; keine Wiedergabe über Lautsprecher oder Kontakt mit dem Pixel.

| Szene | Sprachphasen | Größte Phase | Aktiv darin | Pausen darin | Annotierte Wortzeit überdeckt |
|---|---:|---:|---:|---:|---:|
| EN2002b Headset | 2 | 18:55,695 | 16:29,445 | 2:26,250 | 94,1 % |
| EN2002b Array1-01 | 2 | 18:55,215 | 15:29,160 | 3:26,055 | 88,7 % |
| EN2006a Array1-01 | 1 | 19:59,535 | 16:02,160 | 3:57,375 | 94,9 % |

**Gegenbefund:** EN2002b behält eine kurze Anfangsphase vor der Pause getrennt. Die 20%-Mindestaktivität verhindert hier das Verbinden, obwohl der Abstand unter 90 Sekunden liegt. Kein Retuning auf Testaufnahmen. Im Headset zusätzlich 1,455 Sekunden ungeprüfter Musikhinweis; ohne separate Grundwahrheit weder tatsächliche Musik noch bewiesener Fehlalarm.

Wortzeit-Überdeckung = Schnittmenge Modellaktivität/manuelle Wortintervalle geteilt durch Wortzeit. **Keine allgemeine Klassifikationsgenauigkeit.** Modellfenster überdecken auch Pausen, Wortannotationen nicht alle Lautäußerungen. Die entsprechende Präzisionsgröße steht im [bereinigten Ergebnis](natural-conversations-2026-11-05.json). Keine Belästigung, Gesprächsinhalte, Personen, gemeinsame Ursache, deutsche Alltagssprache oder Übertragung durch Wände validiert.

## Prüfungen

- 191 Backendtests bestanden, 2 bestehende Tests übersprungen, darunter 14 neue Vertrags-/Zugriffs-/Löschprüfungen.
- 93 Fluttertests bestanden; gesondert konfigurierter HTTP-Test dabei ausgelassen. Analyse ohne Befund. Zehn Queue-Tests und UI-Prüfung bei 390/320 Pixel Breite: Zustimmung, Abbruch, Empfangsstatus und asynchroner Löschabschluss.
- **Zusätzlicher echter HTTP-Test bestanden:** tatsächlicher `ApiClientService`, eigene FastAPI-App, PostgreSQL 16 und verschlüsselte SQLite-Queue. EN2006a trotz Offline-Zeit und verlorener Antwort als eine 19:59,535-Phase mit 20 Revisionen bestätigt. Neustart beendet eine weitere Phase als unterbrochen; anschließende Remote-Löschung bestätigt. Beschleunigter Frame-Replay, kein 20-minütiger Geräte-/Netzlauf.
- PostgreSQL: gleichzeitige Erstanlage, vertauschte Revisionen und DELETE-/PUT-Rennen ohne Duplikate oder Wiederherstellung gelöschter Inhalte; Migration bestanden.
- Android-Debug-Build `.phaseuploadqa` erfolgreich; APK-ZIP und alle 13 geprüften nativen Bibliotheken bestehen die statische 16-KB-Prüfung. SHA-256 `c71fdc46c0611bd02ca71d7b43f18b977c4ee6d8da8b0fd261920a653d591dc1`. Keine Installation dieses Stands, kein neuer physischer iOS-Test, kein Produktions-Deployment.
- HTML-Bericht im Browser bei 1280/390 Pixel geprüft, kein horizontaler Überlauf; Schalter blendet den Elternrahmen aus und erhält 183 aktive Sprachintervalle.

## Reproduzieren und offene Grenzen

`scripts/test-natural-conversations.py --root <externer_fixture_ordner>` prüft SHA-256 explizit bereitgestellter Dateien, führt TensorFlow-Lite-Inferenz aus und ruft `scripts/acoustic-phases.dart` auf. `protocol` und `fixtures` im Ergebnis-JSON liefern `natural-scene-plan.json` und `natural-fixture-manifest.json`. Benötigt: Python mit TensorFlow, NumPy, soundfile; Dart und mobile Abhängigkeiten. Audio/Annotationen außerhalb von Git. Ausgewertet werden Zeitattribute; keine Gesprächsinhalte im Bericht.

`scripts/source-phase-integration-server.py --config <private_config.json>` akzeptiert ausschließlich eine ausdrücklich temporäre Docker-Datenbank `source_phase_qa` mit Eigentumsmarke und Loopback-Port. Konfiguration mit kurzlebigen Zugangsdaten niemals committen. Danach aus `mobile`: `ONN_PHASE_FIXTURES=<ordner> ONN_PHASE_QA_URL=http://127.0.0.1:<port>/api/v1 flutter test test/services/source_phase_http_test.dart`. Besondere Flutter-Testbindung ermöglicht echte HTTP-Anfragen nur für diesen expliziten Loopback-Test. Eigene Testdienste nach Abschluss gezielt beenden.

`scripts/render-natural-phase-report.py --root <ordner> --output <bericht.html>` erzeugt einen vollständig lokalen Bericht aus tatsächlichen Resultaten. Elternphasen und aktive Teilintervalle getrennt; Schalter blendet Elternrahmen aus. Keine privaten Feldtestwerte werden gelesen.

Offen: physische Validierung nach R2, echter HTTPS-Weg mit neuer API, Last/Backups, automatische serverseitige Aufbewahrungsbereinigung und Betrieb der Löschmarken. Bestätigte Queue-Einträge bleiben für spätere gezielte Löschung erhalten; Langzeitwachstum und maximal 20.000 Intervalle pro Phase sind Grenzen. Überschreitung wird sichtbar blockiert statt verworfen. Kein formaler Datenschutz-, Kalibrierungs- oder Release-Nachweis.
