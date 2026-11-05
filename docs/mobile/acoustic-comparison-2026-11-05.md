# Geräuschphasen: Implementierung und lokaler Modellvergleich

Stand: 05.11.2026. Die neue Zeitlogik löst die geprüfte Zersplitterung bereits mit YAMNet. EmbeddingGemma 2 wurde wirklich lokal ausgeführt, zeigt aber in diesem begrenzten Versuch keinen klaren Vorteil für den laufenden Sensor. **YAMNet bleibt in der App; Pixel R2 wurde weder aktualisiert noch unterbrochen.** Maßgeblicher Arbeitsstand: [current-status](../current-status.md).

## Implementiertes Verhalten

`source_phases_v1` bildet pro Quellenfamilie zusammenhängende Phasen unabhängig von einer Pegelschwelle. Mehrere gestützte Kategorien können gleichzeitig aktiv sein. Die gleiche reine Dart-Funktion erzeugt App-Karten, Export und Prüfergebnisse. Zeitlich überlappende Hinweise werden vereinigt, nicht doppelt gezählt. Explizite Inferenzabdeckung wird mit der bereits aktivierbaren privaten Historie verschlüsselt gespeichert; kein zusätzliches Audio oder Embedding wird aufbewahrt.

Kurze Pausen werden nur bei ausreichender jüngster Aktivität geschlossen. Sprache erhält zunächst 90 Sekunden maximale Pause und mindestens 20% Aktivität im zurückliegenden Fenster von höchstens fünf Minuten. Die Quote wird vor dem neuen Abschnitt ausgewertet: Eine spätere lange Aktivität darf eine vorherige dünne Kette nicht nachträglich legitimieren. Andere Familien besitzen eigene Pausengrenzen. Echte Abdeckungslücken trennen immer. Grenzen, aktive Zeit und Zwischenräume sind erklärbar; „Sprachaktivität“ beweist weder Unterhaltung noch anwesende Personen oder Belästigung. Pegel gelten für die gesamte gemischte Szene.

Alte Historie ohne Abdeckungsdaten kann nicht nachträglich diese Kontinuität belegen. Der laufende Pixel-Build hat die neue Erfassung noch nicht. Vorhandene Pegelblöcke bleiben verfügbar. Die lokale Phase ist außerdem noch kein Serverereignis: Schwellen-Upload und Backend-Zeitlogik wurden nicht verändert.

## Bekannte Szenen und Ergebnis

| Prüfung | Ergebnis | Aussagegrenze |
|---|---|---|
| Reine Intervalle, 33 Minuten Sprache mit 20 s Aktivität / 10 s Pause und kurzem Türereignis | Ein 33-Minuten-Elternblock; aktive Zeit 1.330 s, Zwischenräume 650 s | Vorgegebene Hinweise, keine Audioerkennung |
| Reale Klassifikation kurzer Prüfclips, nach 33-Minuten-Zeitplan wiedergegeben | Beide Modelle: 66 Quellenintervalle → eine Phase von 1.979,535 s | Wiedergabe von Modellentscheidungen, kein 33-Minuten-Audiolauf |
| Lange Pause, künstliche Inferenzlücke, dünne Einzelimpulse | Lange Pause/Lücke trennen; 1-s-Impulse pro Minute bleiben getrennt | Deterministische Negativfälle |
| Fünfminütige PCM-Spur, gleitende echte Inferenz | Beide Modelle und vorhandener YAMNet-App-Kopf: zwei Sprachphasen nahe 0–80 s und 210–290 s | Künstlich zusammengesetzter Monolog, keine natürliche Unterhaltung |
| Dieselbe PCM-Spur mit ausgelassenen Fenstern von 250–255 s | Zweite Phase wird bei beiden Modellen getrennt | Kontrollierter Analyseausfall |

Die PCM-Spur enthält sechs 20-Sekunden-Sprachabschnitte mit je zehn Sekunden Zwischenraum sowie Türklopfen ab Sekunde 45 und 235. Zwischen den beiden Sprachblöcken liegt eine längere Pause. 268 nicht vollständig nullwertige Fenster wurden tatsächlich inferiert; nur exakt erzeugte digitale Stille wurde bei beiden Modellen gleichermaßen übersprungen. Das ist kein produktiver Stilledetektor.

## Modellvergleich: getrennte Entwicklungs- und Prüfdateien

24 Dateien, sechs Klassen, je zwei Entwicklungs- und zwei Prüfdateien: Hund, Handsäge, Türklopfen, Regen, Autohupe und synthetischer Monolog. Umweltgeräusche stammen aus ESC-50 (Entwicklung Fold 1, Prüfung Fold 5), Sprachdateien aus lokalem macOS `say` (Entwicklung Samantha, Prüfung Daniel). Die Quellaufnahmen überschneiden sich zwischen den Mengen nicht. Die Quellen, Aufnahmekennungen und SHA-256-Werte stehen in [den bereinigten Ergebnisdaten](acoustic-comparison-2026-11-05.json). Modell-Vortraining auf öffentlichen Beispielen kann nicht ausgeschlossen werden.

Beide Modelle erhalten dieselben ersten 77.040 Samples (4,815 s) in Mono bei 16 kHz. YAMNet liefert gemittelte 521 Klassenscores aus 975-ms-Fenstern; Gemma liefert einen maskiert gemittelten und L2-normalisierten 768-dimensionalen Audiovektor. Beide verwenden denselben einfachen Nächster-Schwerpunkt-Klassifikator mit ausschließlich den Entwicklungsdateien. Dieser geschlossene Vergleich muss eine der sechs Klassen wählen und ist kein kalibrierter Produktionsklassifikator mit geprüfter Enthaltung.

| Verfahren | Richtige Prüfclips | Median je 4,815 s Audio | Spitzen-RSS des gesamten Python-Prozesses |
|---|---:|---:|---:|
| YAMNet + Vergleichsklassifikator | 10/12 | 4,83 ms | 0,41 GiB |
| EmbeddingGemma 2 + Vergleichsklassifikator | 12/12 | 400,09 ms | 2,72 GiB |

Die bestehende YAMNet-App-Zuordnung trifft separat 8/12 Quellenfamilien auf den gemittelten Clip-Scores. Das ist ein anderes Klassifikationsverfahren und kein Beleg, dass YAMNet grundsätzlich nur diese Genauigkeit erreicht. YAMNet-Embeddings wurden nicht verglichen; das konkrete TFLite-Artefakt liefert hier Scores. Laufzeit: zwei CPU-Threads auf diesem Mac, separate Prozesse. Gemma läuft mit Float32; kein quantisierter/optimierter Mobilvergleich. Keine Aussage zu Pixel-Akku, Wärme oder Mobil-RAM daraus ableiten.

### Streamingvergleich und negativer Befund

Im ersten Fünfminutenlauf wurden die aus 4,815-s-Clips gebildeten Klassenmittel auf 975-ms-Fenster angewandt. Gemma fand die Sprachphasen, lieferte aber **59,805 Sekunden falsche Verkehrsaktivität**. YAMNet lieferte 1,455 Sekunden falschen Verkehr. Dieser Kontextwechsel begrenzt die Aussage des ersten Versuchs.

Daraufhin wurden beide Vergleichsköpfe erneut ausschließlich mit 975-ms-Fenstern der ursprünglichen Entwicklungsdateien gebildet. Derselbe Prüfablauf wurde wiederverwendet: **explorative Protokollkorrektur, keine neue unabhängige Validierung.** Keine Anpassung von Klassenmitteln an die Prüfdateien und keine weitere Optimierung auf dieses Ergebnis.

| Gleich lange Entwicklungs-/Prüffenster | Erkannte Sprachspannen | Zusätzliche falsche Quellenfamilie | Reine Inferenzzeit, 268 Fenster |
|---|---|---|---:|
| YAMNet + Vergleichskopf | 0–80,655 s; 209,280–290,895 s | Tiergeräusch, 1,455 s aktiv | 0,345 s |
| Gemma + Vergleichskopf | 0–80,655 s; 209,280–290,415 s | Verkehr, 1,935 s aktiv | 70,690 s |
| Bestehender YAMNet-App-Kopf | dieselben zwei YAMNet-Sprachspannen | keine zusätzliche Familie in dieser Spur | dieselbe YAMNet-Inferenz |

Die zeitliche Erkennung der Klopfgeräusche ist unvollständig. Der verbesserte Gemma-Wert beseitigt den Quellenfehler nicht. Einzelclip-Ergebnis und Episoden-Ergebnis sind unterschiedliche Prüfungen. Weder ein synthetischer Monolog noch das Wiederholen kurzer Clips testet echte Gespräche, TV, Identität einer Quelle, Nachbarräume oder Belästigung.

## Reproduzierbarkeit und Artefakte

- YAMNet: vorhandenes `mobile/assets/models/yamnet.tflite`, SHA-256 `4d8b4a53282dc83ef04e3e7dbc4fbc98082e34e44ed798e16c3a0cdd4c584faf`.
- Gemma: `google/embeddinggemma-2`, Revision `f9972ac22e696a105c482202646979e33e4b5a1e`; Audio aktiv, `vision_config=None`, maskiertes Mittel der letzten Hidden States, L2-Normierung. Transformers 5.21.1, PyTorch 2.15.0; lokale Gewichte, keine Cloud-Inferenz.
- Abhängigkeiten mit `uv` in einer separaten Umgebung auf dem externen Datenträger installiert. Gewichtedateien, Vektoren, synthetisches Audio und vollständige Resultate unter `/Volumes/RetroData/OpenNoiseNet-model-comparison-20261105/`, außerhalb des Repositories. ESC-50 ist CC BY-NC 3.0; Audiodateien werden hier nicht weitergegeben. Die Sprachdateien sind lokal erzeugte Testartefakte, ebenfalls nicht weitergegeben. Wiederholung benötigt diese expliziten lokalen Fixtures; andere TTS-Versionen erzeugen nicht zwingend dieselben Hashes.
- `benchmark-acoustic-models.py` prüft Dateihashes und getrennte Quellaufnahmen; je Modell eigener Prozess. `replay-acoustic-scenes.py` und `run-acoustic-audio-scene.py` rufen den tatsächlichen Dart-Kern auf. Die Programme greifen weder auf Mikrofon noch ADB zu und spielen nichts ab.
- `render-acoustic-comparison.py` erzeugt den offline lesbaren Bericht mit Zeitspuren, aktiven Intervallen, Grenzen und negativen Befunden. Lokales Ergebnis: `~/Library/Application Support/OpenNoiseNet/Modelvergleich-2026-11-05/vergleich.html`.

Beispiel mit vorbereitetem Manifest und Modellordner (Python aus der mit `uv` angelegten Umgebung):

```sh
python scripts/benchmark-acoustic-models.py --root "$COMPARISON_ROOT" --model yamnet --yamnet mobile/assets/models/yamnet.tflite
python scripts/benchmark-acoustic-models.py --root "$COMPARISON_ROOT" --model gemma
python scripts/benchmark-acoustic-models.py --root "$COMPARISON_ROOT" --model compare
python scripts/replay-acoustic-scenes.py --root "$COMPARISON_ROOT"
python scripts/run-acoustic-audio-scene.py --root "$COMPARISON_ROOT" --model yamnet
python scripts/run-acoustic-audio-scene.py --root "$COMPARISON_ROOT" --model gemma
python scripts/run-acoustic-audio-scene.py --root "$COMPARISON_ROOT" --model yamnet --matched-windows
python scripts/run-acoustic-audio-scene.py --root "$COMPARISON_ROOT" --model gemma --matched-windows
python scripts/render-acoustic-comparison.py --root "$COMPARISON_ROOT" --output /private/path/vergleich.html
```

## Technische Prüfung und verbleibende Abnahme

82 Flutter-Tests und Analyse erfolgreich, einschließlich Quellenüberlagerung, echter Lücke, verschlüsselter Abdeckung, Löschen/Deaktivieren, Legacy-Daten, Exportfenster und Phasenansicht bei 390 × 844. Android-Debugpaket `.phaseqa` gebaut und statisch auf 16-KB-Ausrichtung geprüft (13 native Bibliotheken); **nicht installiert**. Python-Grafik-/Nachbereitungstests 10/10, JavaScript-Pegelepisoden 3/3. HTML im lokalen Browser ohne horizontales Seitenüberlaufen geprüft. Dies ist keine neue physische Android-/iOS-Prüfung und kein Release-Build.

Nächste fachliche Nachweise nach R2: separate Installation mit echten Abdeckungsdaten, unabhängige natürliche Szenen mit markierten Zeitgrenzen und Quellen, Fehlalarme/Enthaltung sowie Ressourcenbedarf auf dem Zielgerät. Erst danach lässt sich die Alltagserkennung bewerten. Quellenbasierter Upload mit Fortsetzung und eindeutiger Episodenbedeutung bleibt eigene Integrationsarbeit. Keine neuen Rohaufnahmen, keine privaten Messdaten in Git/Vault, keine Änderungen am laufenden R2-Test.

Primärquellen zur Einordnung: [Google-Modellkarte EmbeddingGemma 2](https://ai.google.dev/gemma/docs/embeddinggemma/model_card_2), [TensorFlow-YAMNet-Referenz](https://www.tensorflow.org/hub/tutorials/yamnet), [ESC-50 und Lizenz](https://github.com/karolpiczak/ESC-50). Die obigen Zahlen sind eigene lokale Ergebnisse, keine Herstellerbenchmarks.
