# Akustikbüros und persönliches Lärmtagebuch

Stand: 3. November 2026. Arbeitsunterlage für die Untersuchung des kommerziellen Potenzials; keine Gesprächsergebnisse, Kundenbeziehungen, zugesagten Piloten oder Produktentscheidungen. Ausgangspunkt: [Kommerzielle Erkundung](commercial-potential-2026-11-03.md), technischer Maßstab: [aktueller Projektstand](current-status.md).

**Spätere Ergänzung am 03.11.:** Ein erster manueller Tagebuch-Prototyp wurde inzwischen lokal implementiert und auf einem separaten iOS-Simulator geprüft. Er setzt nicht den gesamten unten skizzierten Ablauf um: automatische App-Hinweise, Export und ein geprüftes vollständiges Löschkonzept bleiben offen. Die Einladungsvorbereitung steht in der [Arbeitsmappe](acoustics-first-conversations-drafts.md).

## 1. Hypothese für Akustikbüros

**Problem ohne Lösungsannahme:** Wenn ein schwer vorhersehbares Geräusch bei einer Ortsbegehung gerade nicht auftritt, könnte es für ein Akustikbüro aufwendig sein zu entscheiden, wann und wo eine fachliche Messung angesetzt werden soll. Ob das in relevanter Häufigkeit vorkommt und wie Büros es heute lösen, ist unbekannt.

**Wer:** Kleine oder mittlere unabhängige Akustik- und Sachverständigenbüros in Deutschland mit tatsächlichen Aufträgen zu wiederkehrenden Geräuschimmissionen; Interviewpartner möglichst mit eigener Projekterfahrung, bei einigen zusätzlich Budgetverantwortung. Nutzung durch Projektleitung oder Messtechniker; Beschaffung und Zahlung möglicherweise durch Inhaber oder Auftraggeber. Diese Rollen sind zunächst zu erfragen.

**Prüfbare Wertannahme:** Ein Büro, das einen solchen Fall bereits bearbeitet, kann anhand einer nachvollziehbaren, vorläufigen Übersicht von Zeiten und wahrscheinlichen Geräuscharten besser beurteilen, wann es eine fachliche Messung plant. Das müsste gegenüber dem konkreten bisherigen Vorgehen einen von ihm benennbaren Vorteil erzeugen, etwa eine andere Messplanung oder weniger Abstimmungsaufwand. Kategorien bleiben Hinweise, keine Quellenidentifikation und kein Beweis.

**Kritische Gegenhypothese:** Solche Fälle sind zu selten; vorhandene Profi-Messgeräte, manuelle Protokolle oder der unmittelbare Ortstermin lösen sie bereits ausreichend. Eine Smartphone-Übersicht könnte zusätzliche Unsicherheit und Abstimmungsarbeit erzeugen oder fachlich unbrauchbar sein. Diese Möglichkeit wird gleichwertig dokumentiert.

**Preis-/Kaufannahme:** Falls sich ein Nutzen zeigt, könnte ein Büro für einen zeitlich befristeten betreuten Vorversuch oder einen nachgewiesenen Arbeitsablauf bezahlen. Weder Preis noch Häufigkeit noch Budget sind bekannt. Nicht mit einem erfundenen Kostenersparnis- oder Genauigkeitsversprechen argumentieren.

## 2. Plan für sechs Gespräche

### Auswahl und Vorbereitung

- Sechs voneinander unabhängige Gesprächspartner aus unterschiedlichen Büros suchen, möglichst mit verschiedenen Arten von realen Fällen. Einschluss: Sie haben in den letzten zwölf Monaten selbst Projekte mit wiederkehrenden oder schwer terminierbaren Geräuschen begleitet. Bei einzelnen außerdem erkunden, wer Budget oder Beschaffung verantwortet. Unterschiedliche Regionen oder Arbeitsgebiete anstreben; dies ist eine kleine qualitative Stichprobe, keine repräsentative Erhebung.
- Recherchierte **Kandidaten**, noch nicht kontaktiert und ohne Aussage zu Größe, Interesse oder Eignung für das konkrete Problem: [IBAB, Hannover – Messungen in Bauakustik und Schallschutz](https://www.ibab.info/messungen/); [Ingenieurbüro Axel C. Rahn, Berlin – Schallmessungen und messtechnische Ursachenklärung](https://ib-rahn.de/leistungen/bau-und-raumakustik/schallmessungen/); [le-acoustics, Hamburg – Lärmüberwachung und Schallimmissionsschutz](https://www.le-acoustics.com/); [Bergann Anhaus, Hamburg – schalltechnische Untersuchungen und Lärmgutachten](https://www.iba-anhaus.de/contact/). Zwei weitere Büros nach denselben Kriterien ergänzen; Verzeichnisse wie die [IHK Aachen](https://www.ihk.de/aachen/recht/sachverstaendige/sachverstaendigenverzeichnis/schallschutz-607736) können dabei helfen. Öffentliche Leistungsbeschreibungen belegen weder ein konkretes Problem noch Zahlungsbereitschaft.
- Gespräche von ungefähr 30 Minuten vorsehen; tatsächlichen Aufwand erfassen. Auf freiwillige Teilnahme hinweisen, keine Kundennamen oder vertraulichen Unterlagen erbitten. Notizen nur mit Einverständnis, standardmäßig ohne personenbezogene Fallangaben; keine Gesprächsaufnahme voraussetzen. Teilnahme und Ablehnung ohne Druck ermöglichen.
- Vorher ein unverändertes, eindeutig als synthetisch markiertes Beispiel und den Stand der App bereitlegen. Den laufenden Pixel-Test nicht als Demo unterbrechen. Keine Daten eines Dritten verwenden; nach Möglichkeit [den bereits dokumentierten Emulator-Screenshot](evidence/android-17-16kb-release-tone.png) für eine technische Illustration nutzen und erklären, dass ein Testton keine reale Geräuschklasse belegt. Eine Live-Demo ist optional und darf weder Wahrnehmung noch technische Grenzen übertreiben.

### Gesprächsleitfaden

**0–3 Minuten – Rahmen.** „Ich untersuche, wie Akustikbüros schwer vorhersehbare Geräuschereignisse in der Vorbereitung einer Messung handhaben. Mich interessieren auch Fälle, in denen ein zusätzlicher Hinweis keinen Nutzen hätte.“ Zustimmung zu anonymisierten Notizen einholen.

**3–15 Minuten – Zuerst der echte Fall.**

1. „Denken Sie an einen konkreten Auftrag aus dem letzten Jahr, bei dem ein Geräusch nicht zuverlässig zum gewünschten Zeitpunkt auftrat. Was war die Aufgabe?“
2. „Wie sind Sie dabei vorgegangen – von der ersten Meldung bis zur Entscheidung über die Messung?“
3. „Welche Informationen lagen wann vor? Welche Geräte, Protokolle oder Personen haben geholfen?“
4. „Wo entstand zusätzlicher Aufwand oder Unsicherheit? Wie häufig kommt so etwas in Ihrer eigenen Arbeit vor?“
5. „Gab es eine Situation, in der Ihr heutiger Ablauf völlig ausgereicht hat oder zusätzliche Daten eher gestört hätten?“

**15–22 Minuten – Entscheidungsprobe.** Ein als fiktiv gekennzeichnetes Beispiel einer Übersicht zeigen: Datum, Zeitfenster, möglicher Geräuschtyp, ausdrücklich unbekannte Quelle, erkennbare Messlücken. Fragen: „An welcher Stelle Ihres geschilderten Falls wäre das hilfreich oder wertlos gewesen? Welche konkrete Entscheidung wäre anders ausgefallen? Was würden Sie als Erstes überprüfen? Welche Fehler wären nicht akzeptabel?“ Zusätzlich fragen, welche Daten und Genauigkeit unverzichtbar wären und ob ihre eigene Ausrüstung diesen Bedarf bereits abdeckt.

**22–27 Minuten – Kauf und Einführung.** „Wofür wird heute in solchen Fällen Zeit oder Geld aufgewendet? Wer entscheidet über zusätzliche Hilfsmittel? Was müsste ein Vorversuch nachweisen, bevor Sie dafür ein Budget einsetzen? Aus welchem bestehenden Budget oder welcher Projektleistung käme es?“ Preis nur als offene Frage behandeln; Interesse an einem späteren entgeltlichen Test ist keine Bestellung.

**27–30 Minuten – Gegenprüfung.** „Was spricht aus Ihrer Sicht am stärksten dagegen? Welche Fachperson würde diese Idee vermutlich anders bewerten?“ Falls gewünscht, eine Rückmeldung zu den anonymisierten Kernaussagen anbieten. Keine Kontaktdaten oder vertraulichen Dokumente in dieses Repository eintragen.

### Kurzer Einladungstext – Entwurf, nicht versendet

> Guten Tag, ich beschäftige mich mit der Frage, wie Akustikbüros wiederkehrende, schwer vorhersehbare Geräusche vor einer fachlichen Messung einordnen. Ich würde gern Ihren bisherigen Ablauf und seine Grenzen verstehen – ausdrücklich auch, wenn zusätzliche technische Hinweise dafür keinen Nutzen haben. Hätten Sie Zeit für ein unverbindliches Gespräch von etwa 30 Minuten? Vertrauliche Fallangaben benötigen wir nicht. Viele Grüße

Vor einer tatsächlichen Kontaktaufnahme passend personalisieren; keine Massenansprache. Eine Einladung ist hier lediglich vorbereitet.

### Dokumentation und Entscheidung

Je Gespräch ein anonymes Kürzel und Datum, Rolle/Budgetrolle, eigene jüngere Fallschilderung, aktuelles Vorgehen, beobachtbaren Aufwand, Entscheidungsstelle, Gegenargument, konkrete Alternative und etwaiges Budgetsignal festhalten. Wörtliche Aussagen nur mit Zustimmung und sparsam; Zustimmung zu späterem Kontakt getrennt dokumentieren. Nichtteilnahme und Absagen soweit bekannt erfassen. Aussagen nicht als beobachtete Nutzung oder Zahlung ausgeben.

Vorab definierte qualitative Entscheidungshilfe aus der [Erkundung](commercial-potential-2026-11-03.md): mindestens drei von sechs Gesprächspartnern schildern passende eigene Fälle und ihre bisherige Bearbeitung, und mindestens eine Person zeigt ernsthaftes Interesse an einem späteren bezahlten Test. Dann die nächste offene Annahme – tatsächlich bessere Entscheidung gegenüber dem bisherigen Ablauf – gezielt prüfen. Zwei passende Fälle oder bloß unverbindliches Interesse: Segment eingrenzen und anders prüfen. Höchstens ein passender Fall: Akustikbüros vorerst zurückstellen. Die zusätzlichen Gespräche und ein tatsächlicher Pilot sind nicht durchgeführt; ein Interessenbekunden ist kein Auftrag und kein Nachweis bezahlter Nachfrage. Sicherheits- und Betriebsgrenzen müssen vor einem echten Test mit Dritten gesondert geklärt werden.

## 3. Persönliches Lärmtagebuch – Untersuchung

### Situation und bestehende Alternativen

Eine betroffene Person möchte nach wiederholten Geräuschereignissen nachvollziehen, was sie wann erlebt hat, und ihre eigene Erinnerung festhalten. Sie kann ein Papierprotokoll, eine Notizen-App, eine Vorlage oder eine freie App verwenden. Die [GESOBAU-Vorlage](https://www.gesobau.de/fileadmin/user_upload/03_Wohnen/3.1_Rund_ums_Wohnen/Wohnen_Dateien_Bilder/Infocenter/08_Laermprotokoll.pdf) illustriert die heute verwendeten Felder wie Datum, Uhrzeit, Art und Bemerkung. Sie belegt nicht, dass ein automatisiertes Tagebuch besser ist.

Möglicher Mehrwert: selbst festgehaltene Eindrücke und optionale Geräuschhinweise in einem überschaubaren Verlauf zusammenführen. Dabei kann die App eine Belastung weder objektiv für die Person bewerten noch einen Verursacher feststellen. Die betroffene Person entscheidet, was sie teilt.

### Gedanklicher Ablauf – noch kein implementiertes Produkt

1. **Ohne Konto beginnen:** Ein persönlicher Bereich mit der Wahl „Eintrag selbst hinzufügen“ oder „Geräuschbeobachtung starten“. Nur letzteres würde das Mikrofon benötigen; zuerst erklären, was verarbeitet und gespeichert wird. Standort wäre für ein privates Tagebuch nicht nötig.
2. **Ereignis festhalten:** Datum und ungefähren Beginn wählen, Ende oder Dauer ergänzen, wenn bekannt. Eigene Beschreibung und persönliche Auswirkung können freiwillig hinzukommen; Unbekanntes bleibt leer. Ein Eintrag darf auch ohne automatisch erkanntes Ereignis entstehen.
3. **Hinweise prüfen:** Eine mögliche Modellkategorie erscheint klar als „App-Vorschlag“ neben der eigenen Beobachtung. Die Person kann sie bestätigen, korrigieren, als unbekannt stehen lassen oder ausblenden. Die ursprüngliche automatische Einschätzung und die spätere persönliche Änderung bleiben unterscheidbar. Keine Person oder Wohnung automatisch beschuldigen.
4. **Verlauf betrachten:** Tage und Zeitfenster zeigen eigene Einträge, optionale App-Hinweise und erkennbare Beobachtungslücken. „Keine Daten“ bedeutet nicht „es war ruhig“. Unterbrechungen, unbekannte Dauer und abweichende Zeitzone müssen sichtbar sein; keine Vollständigkeit suggerieren.
5. **Bei Bedarf teilen:** Eine Vorschau zeigt ausgewählte Angaben, Zeitraum und mögliche Empfänger; die Person löst den Export selbst aus. Keine automatische Kartenveröffentlichung oder Weitergabe. Exportierte Kopien liegen nach Weitergabe außerhalb der Kontrolle der App.
6. **Aufbewahren und löschen:** Einträge und optionale Ereignisdaten getrennt überblicken und löschen können. Vor einer Realisierung sind lokaler Speicher, Gerätesicherung, eventuelle Synchronisation, Löschfristen und Wirkung bei Exporten zu entwerfen und zu prüfen; eine automatische vollständige Löschung besteht derzeit nicht.

**Fiktive Ansicht:**

> Dienstag · 22:35–22:42<br>
> App-Hinweis: wiederholte dumpfe Geräusche – Quelle unbekannt<br>
> Meine Beobachtung: „Hat mich beim Einschlafen gestört.“<br>
> Beobachtung unterbrochen 22:40–22:41 · Eintrag prüfen

Dieses Beispiel beschreibt ein mögliches Interface, keinen realen Messdatensatz und keine bestätigte Erkennungsfähigkeit.

### Schutz und Grenzen

- Ein privates Tagebuch soll ohne automatische Veröffentlichung und ohne Standort funktionieren; eine spätere Synchronisation wäre eine eigene ausdrückliche Entscheidung. Das ist eine Produktannahme, nicht als vollständige gegenwärtige App-Funktion nachgewiesen. Das bestehende System kann strukturierte Ereignisse hochladen, wenn dies eingerichtet ist.
- Neue Audiodateien sind im aktuellen Entwicklungsstand vorübergehend gesperrt; eine Freigabe oder Änderung der Aufnahmepolitik ist nicht Bestandteil dieses Konzepts. Die laufende Pixel-Testinstallation ist älter und wurde nicht verändert. Auch Ereignisart und Uhrzeit können sensibel sein.
- Der gegenwärtige Pegel ist keine validierte dB(A)-Schalldruckmessung. Keine amtliche Messung, gerichtsfestes Beweismittel, Ursachennachweis oder garantierte Vollständigkeit versprechen.
- Eine App kann Konflikte verschärfen oder persönliche Selbstbeobachtung belasten. Keine automatische Benachrichtigung Dritter, Schuldzuweisung oder Selbstdiagnose. Der Nutzen ist genauso gegen Papier und Nichtstun zu prüfen.

### Bestand versus Konzept

Die mobile App zeigt bereits live lokale Quellenhypothesen und Aktivitäten; strukturierte Ereignisse und eine Backend-Ereignisverarbeitung existieren. Die Pro-Weboberfläche hat Fall- und Exportansätze, die für einen privaten mobilen Tagebuchablauf nicht automatisch übernommen werden können. Ein persönliches, manuell ergänzbares Tagebuch mit den oben beschriebenen Korrekturen, Vorschauen, Lücken und Löschgarantien ist durch diese Recherche nicht als vorhanden belegt.

### Erkenntnisreicher nächster Vergleich

Drei bis fünf Betroffene mit eigenen wiederkehrenden Erfahrungen könnten erst ihren tatsächlichen bisherigen Umgang beschreiben und danach anhand eines fiktiven Protokolls vergleichen: Welche Angabe würden sie selbst führen, korrigieren oder nie speichern? Entlastet die Oberfläche gegenüber Papier oder macht sie die Situation aufwendiger? Getrennt fragen, ob ein einmaliger Kauf, freiwillige Unterstützung oder gar keine Zahlung in Betracht käme. Das ist ein Vorschlag; keine Teilnehmer wurden rekrutiert und keine Produktänderung ist beauftragt.
