# Geräuschphasen verstehen: Konzept und Modellvergleich

Stand: 05.11.2026. **Analyse und Vorschlag, noch keine Implementierung oder Modellentscheidung.** Der laufende Pixel-Test R2 bleibt unverändert. Maßgeblicher Arbeitsstand: [current-status](../current-status.md).

## Anforderung von Udi

Einzelne Erkennungen und kurze Pegelereignisse erfüllen den Kernnutzen noch nicht. Gesucht sind nachvollziehbare, möglichst große zusammenhängende Geräuschphasen: wann, wie lange, welche möglichen Geräuscharten und welche Pegel. Unterhaltung mit Pausen ist ein wichtiger Prüffall. „Möglichst groß“ heißt unter einer belegbaren Kontinuitätsregel maximal; es darf nicht durch beliebiges Verlängern der Pausentoleranz ein Tagesblock entstehen.

## Belegter Ist-Zustand

Codebasis: `d39047d` / Implementierung `bdc8290`. Die folgende Diagnose erklärt strukturelle Grenzen; sie ist keine frameweise Auswertung einer konkreten privaten Alltagsszene.

- `yamnet_inference_engine_native.dart`: lokales TFLite-YAMNet, 15.600 Samples bei 16 kHz, 521 Klassenscores. Der aktuelle Adapter liest Scores, keine Audio-Embeddings. Keine EmbeddingGemma-/Gemini-Einbindung in den geprüften App-/Backend-Laufzeitquellen und Abhängigkeiten.
- `on_device_sound_analysis_service.dart`: 975-ms-Fenster alle 480 ms. PCM nur begrenzt im Arbeitsspeicher. Klassenscores werden vorübergehend gehalten.
- `open_noise_taxonomy_head.dart`: „Speech“, „Conversation“, „Chatter“ usw. werden bereits berücksichtigt. Gewichtetes Pooling, anschließend eine Gewinnerkategorie. `loud_conversation` folgt dabei dem Klangklassenscore, nicht einem kalibrierten Lautheitsnachweis; „Speech“ beweist weder Unterhaltung noch mehrere Personen oder eine reale anwesende Quelle gegenüber TV/Radio. Die Kategorie sollte fachlich neutraler werden.
- `sound_source_activity_tracker.dart`: zwei passende Fenster aktivieren/wechseln die Kategorie; drei fehlende Fenster beenden sie. Dies stabilisiert kurze Hinweise, bildet aber keine Gesprächsphase über Minuten.
- `noise_history.dart`: Quellenblöcke verbinden nur unmittelbar aufeinanderfolgende gleiche Kategorien mit höchstens einer Minute Abstand. Ein anders klassifiziertes Zwischensegment trennt die Darstellung. Die gespeicherte Historie enthält Kategorie, Zeit und Score; unbekannte Kategorien werden verworfen. Aus fehlenden Einträgen lässt sich deshalb weder Stille noch intakte Inferenz ableiten.
- Dieselbe Datei und `scripts/noise-episodes.js`: die längsten Blöcke beruhen ausschließlich auf Pegelminuten und einer Vergleichslinie (UI-Startwert fünf Minuten Pausentoleranz). Quellen werden nachträglich angehängt; sie entscheiden nicht über die Grenzen.
- `event_detection_service.dart`: Upload-Ereignisse entstehen aus rollendem Leq und Schwelle. Im Backend existiert bereits eine Quellenfamilien-Gruppierung (`anonymous_episode_engine.py`, z. B. 15 Minuten für Sprache). Sie verarbeitet eingegangene Ereignisse und ersetzt nicht die vollständige lokale Quellenzeitreihe. Fehlende Uploads sind kein Beweis für fehlende Sprachaktivität.

Folge: Drei verschiedene Zeitlogiken (kurze Quellenintervalle, Pegelblöcke, Serverereignisse) beantworten noch nicht dieselbe fachliche Frage. Technische Ablauf- und synthetische Zusammenfassungstests sind keine Abnahme der Alltagserkennung.

## Vorgeschlagene gemeinsame Zeitlogik

1. **Beobachtung:** Klassenscores bzw. kleine Familien-Scores, Messpegel und explizite Erfassungs-/Inferenzabdeckung auswerten. Quellen unabhängig davon erkennen, ob eine Pegellinie überschritten wird. Mehrere gleichzeitige Quellen zulassen; keine dauerhafte Speicherung aller Rohscores voraussetzen.
2. **Aktivität:** Über kurze Zeit glätten und für Start/Ende unterschiedliche Kriterien verwenden (Hysterese). Auf Familien wie Sprache, Musik, Verkehr, Werkzeug abbilden. Ein kurzer Türschlag beendet nicht automatisch die gleichzeitig fortgesetzte Sprachaktivität.
3. **Episode:** Pro Familie eine länger lebende Phase mit Zuständen „Kandidat“, „aktiv“, „gemessene Pause“, „beendet“ bilden. Zurückkehrende Aktivität darf eine gemessene Pause schließen, wenn Dauer, jüngster Aktivitätsanteil und fortbestehende Szene dazu passen. Anhaltender Szenenwechsel oder ausreichend lange belegte Abwesenheit beendet die Phase. Pausengrenzen sind zu validierende Parameter, keine universal gültigen fünf oder fünfzehn Minuten.
4. **Mehrere Zeitskalen:** Eine übergeordnete Geräuschphase darf kurze Unterereignisse enthalten. Überlappende Episoden verschiedener Quellen bleiben möglich. Ein einzelner größter Zeitraum ersetzt nicht die Quellen-Spuren. Reine Nähe zweier gleichartiger Signale beweist weder dieselbe Unterhaltung noch dieselben Verursacher.
5. **Grenzen und Erklärung:** Fehlende Erfassung trennt belegte Kontinuität; „unbekannt“ bleibt sichtbar und ist keine Ruhe. Wiederkehrende Einzelimpulse dürfen nicht allein durch eine Kette kurzer Abstände zu stundenlang kontinuierlicher Aktivität werden. Bei mehrdeutigen Grenzen Unsicherheit anzeigen. Algorithmus-/Modellversion, Eingangsabdeckung und Gründe für Zusammenführen/Trennen festhalten.

Eine verständliche Karte zeigt Zeitraum, gesamte Spanne, erkannte aktive Zeit, beobachtete Pausen, Quellenanteile/-abdeckung und Pegel im selben Zeitraum. Pegel der gemischten Szene werden nicht als alleiniger Beitrag der Sprache ausgegeben. Subjektiv erlebte Belästigung bleibt eine getrennte Nutzerangabe.

**Erfundenes Zielbeispiel, keine Messauswertung:** „18:27–19:00 · Sprachaktivität mit Pausen · 33 Minuten Zeitraum · 24 Minuten erkannte Aktivität · 9 Minuten beobachtete Pausen · zwischendurch Türgeräusch“. „Unterhaltung“ erst als spezifischer Modellhinweis, wenn entsprechend geprüft; sonst „Sprachaktivität, möglicherweise Unterhaltung/Medienwiedergabe“.

## Rolle von EmbeddingGemma 2

Google beschreibt **EmbeddingGemma 2** seit 06.10.2026 als lokal nutzbares multimodales Embeddingmodell einschließlich Audio. Die Modellkarte nennt 768 Dimensionen und eine selektiv ladbare Text-/Audio-Konfiguration mit 570 Mio. Parametern. Das ist vom älteren textbezogenen EmbeddingGemma und von der separaten Gemini-Embedding-API zu unterscheiden. Herstellerangaben zur lokalen Ausführung sind kein Dauerbetriebsnachweis auf unserem Pixel 10a.

Möglicher Nutzen: Ähnlichkeit von Klangabschnitten und Vergleich mit geprüften Referenzbeispielen bzw. Beschreibungen als zusätzliche Evidenz für eine Quellenfamilie. Ein Embedding ist ein Merkmalsvektor, keine fertige Episodengrenze oder bestätigte Ursache. Gleiche semantische Klasse heißt nicht dasselbe Ereignis. Kontextlange Audioverarbeitung ist nicht gleich präzise zeitliche Segmentierung.

Auch das ursprüngliche TensorFlow-YAMNet kann Embeddings liefern; unser aktueller TFLite-Adapter nutzt sie nicht. Ein passender Export wäre gesondert zu prüfen. Daher zuerst die fehlende Zeitlogik mit vorhandenen Scores isoliert bewerten, anschließend zusätzliche Audio-Embeddings unter derselben Zeitlogik vergleichen.

Datensparsame Zielrichtung: lokal, ohne Transkript oder Sprecheridentifikation, keine neue Rohaufzeichnung. Audio-Embeddings können trotzdem sensible Information tragen und gelten nicht automatisch als anonym. Keine längeren Audio-Ringpuffer oder persistierten Vektoren aus diesem Konzept ableiten; erforderliche Änderungen an Aufbewahrung und Datenschutz sind gesondert zu entscheiden. Für den ersten Modellvergleich öffentliche, passend lizenzierte oder ausdrücklich freigegebene Testaufnahmen außerhalb des Dauertests verwenden.

## Vorgeschlagener Nachweis vor Integration

1. **Referenzfälle festlegen:** Längere Szenen mit zeitlich markierter Wahrheit: Unterhaltung/Sprechpausen, Monolog/Voice-Kommandos, TV/Radio, Sprache plus Verkehr, Baustelle mit Werkzeugwechsel, echte längere Ruhe, wiederkehrende Einzelimpulse und künstliche Erfassungslücke. Zunächst wenige 20–40-Minuten-Szenen zum Auffinden von Fehlern, nicht als allgemeiner Genauigkeitsnachweis.
2. **Vergleich in Stufen:** A aktuelle Logik; B gemeinsame Zeitlogik mit YAMNet-Scores; C dieselbe Zeitlogik mit Audio-Embeddings (YAMNet-Variante falls verfügbar, EmbeddingGemma 2). So ist erkennbar, ob Gruppierung, Merkmale oder beides helfen. Konkrete Aufnahme/Quelle nur einer Entwicklungs- oder Prüfmenge zuordnen, damit ähnliche Ausschnitte nicht in beiden landen.
3. **Messen:** Zersplitterung einer Referenzepisode; fälschliche Zusammenfassung verschiedener Episoden; Zeitüberschneidung und Start-/Endfehler; aktive Dauer versus Pausen; Quellenverwechslungen einschließlich TV/Monolog und korrektes Enthalten bei Unklarheit. Dazu Inferenzdauer, RAM-Spitze, verworfene Fenster, Wärme und Energie auf Zielhardware.
4. **Vorgeschlagene erste Abnahmekriterien:** Der 33-Minuten-Prüffall mit kurzen Pausen ergibt einen erklärbaren Elternblock; zwei Szenen mit belegter längerer Ruhe bleiben getrennt; jede Erfassungslücke sichtbar; unbekannte Quelle nicht umbenannt; leise Sprachaktivität bleibt unabhängig von Pegelereignissen auffindbar. Ein Modellwechsel muss auf zurückgehaltenen Szenen gegenüber B nützen, ohne Datenabdeckung zu verschlechtern. Grenzwerte und tolerierte Fehler vor der Prüfmenge festlegen.
5. **Erst nach dem laufenden Test integrieren:** Eine versionierte Episodenbedeutung für App, Export/Grafik und Server festlegen. Kleine Upload-Pakete sind Transport, nicht automatisch abgeschlossene Episoden; stabile Episoden-ID, Fortsetzungen und endgültiges Ende bei einer späteren Umsetzung berücksichtigen. Danach eigener Geräte- und Dauervergleich. Der aktuelle R2-Lauf bleibt eine Betriebsprüfung des unveränderten Builds.

Das ist die empfohlene Lernfolge, kein neuer Bauauftrag. Noch keine Modelle heruntergeladen, persönlichen Audiodaten verarbeitet oder App-/Serverlogik geändert.

## Geprüfte Primärquellen (05.11.2026)

- [Google: EmbeddingGemma 2, Ankündigung 06.10.2026](https://blog.google/innovation-and-ai/technology/developers-tools/embeddinggemma-2/): Audio, lokale Nutzung, modulare Encoder. Leistungsangaben stammen vom Hersteller.
- [Google: EmbeddingGemma 2 Modellkarte](https://ai.google.dev/gemma/docs/embeddinggemma/model_card_2): Eingaben, Vektoren, selektives Laden, Einschränkungen.
- [TensorFlow: Sound classification with YAMNet](https://www.tensorflow.org/hub/tutorials/yamnet): 521 Klassen sowie Scores, Embeddings und Spektrogramm im Referenzmodell. Kein Beleg für Embedding-Ausgänge unseres konkreten TFLite-Artefakts.
