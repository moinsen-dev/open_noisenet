# OpenNoiseNet: Kommerzielles Potenzial

Stand der Recherche: 3. November 2026. Diese Untersuchung ergänzt den [aktuellen Projektstand](current-status.md). Sie ist eine offene Entscheidungsgrundlage, keine beschlossene Produktstrategie und kein Nachweis von Kunden, Zahlungsbereitschaft oder Produktreife.

## Ausgangspunkt und Einordnung

Udi beobachtet im laufenden App-Test eine eindrucksvolle Darstellung erkannter Geräuschquellen. Diese eigene Erfahrung belegt einen erlebbaren Produktmoment; sie belegt weder Erkennungsgenauigkeit in anderen Situationen noch Kaufbereitschaft Dritter. Die App berechnet Erkennungsvorschläge lokal aus Audiosignalen. Der derzeitige Pegel ist eine digitale, ungewichtete Schätzung; eine gültige Schalldruckmessung, eine echte Referenzkalibrierung und ein Nachweis zur Erkennung durch Wände stehen aus. Die automatische Löschung von Messungen, die vollständige Datenschutzprüfung und ein für externe Kunden tragfähiger Betrieb fehlen. Details: [Projektstand](current-status.md), [Klassifikation](mobile/on-device-sound-analysis.md).

Die Frage ist daher: Wer hat wiederkehrend Schwierigkeiten, Geräuschereignisse zeitlich einzuordnen und den nächsten Schritt zu wählen – und bei wem kann eine ausdrücklich vorläufige, datensparsame Auswertung den bisherigen Aufwand reduzieren?

## Externe Hinweise und Alternativen

- Das [Umweltbundesamt](https://www.umweltbundesamt.de/tags/nachbarschaftslaerm) berichtet für 2024, dass sich rund 58 % der Befragten durch Nachbarschaftsgeräusche belästigt fühlten. Das ist keine Zahl potenziell zahlender Nutzer und trifft keine Aussage über Schwere oder Häufigkeit einzelner Fälle.
- [NoiseCapture](https://noise-planet.org/noisecapture.html) ist bereits eine kostenlose Open-Source-Android-App für Messungen und gemeinschaftliche Lärmkarten. Die [GESOBAU](https://www.gesobau.de/fileadmin/user_upload/03_Wohnen/3.1_Rund_ums_Wohnen/Wohnen_Dateien_Bilder/Infocenter/08_Laermprotokoll.pdf) stellt eine Lärmprotokoll-Vorlage bereit. Papierprotokolle, Fachleute, Nichtstun und freie Apps sind echte Alternativen.
- [Minut](https://www.minut.com/pricing) bietet kommerzielle Überwachung für Mietobjekte. Die angezeigten US-Tarife liegen bei 5, 10 und 15 US-Dollar je Monat bei jährlicher Abrechnung; Sensoren kosten laut Anbieter zusätzlich. Preis, Funktion und Zielgruppe sind nicht direkt auf OpenNoiseNet übertragbar.
- [NTi MeasurEye](https://www.nti-audio.com/en/products/cloud-software/measureye/) bietet laut Hersteller professionelles Monitoring mit optionaler KI-Geräuschklassifikation. [Munisense](https://munisense.com/products/msgd4-/) nennt ebenfalls Quellenklassen wie Verkehr und Baustellen. Geräuschklassifikation allein ist also kein Alleinstellungsmerkmal; Herstellerangaben belegen auch nicht die tatsächliche Qualität oder die Nachfrage nach unserem Produkt.
- [Airbnb](https://www.airbnb.com/help/article/3061) erlaubt unter Bedingungen ausgewiesene Geräte, die Lautstärke und Dauer ohne Audioaufzeichnung erfassen; in Schlafräumen und Bädern sind sie untersagt. Ob eine konkrete quellenerkennende App unter diese Definition fällt, ist nicht geklärt. Ferienwohnungen sind deshalb kein sicherer kurzfristiger Vertriebskanal.

Quellen wurden am 3. November 2026 abgerufen. Die ältere [DACH-Recherche](research-laermbelastung-dach-und-foerderung-2026.md) enthält weitere Quellen zu Umweltbelastung und öffentlichen Vorhaben; daraus folgen keine nachgewiesenen Käufer.

## Zielgruppen und Anwendungshypothesen

| Zielgruppe und Käufer | Auslöser und denkbarer Nutzen | Alternativen und größte Hürde | Vorläufige Rolle |
| --- | --- | --- | --- |
| Kleine Akustikbüros; Inhaber oder Projektleitung zahlen | Bei wiederkehrenden oder schwer terminierbaren Geräuschen könnten Zeitmuster und überprüfbare Kategorien die Planung einer anschließenden Fachmessung unterstützen. | Schon professionelle Sensoren und Arbeitsabläufe vorhanden; unklar, ob Smartphone-Daten jemals genug Mehrwert bringen. Kein Ersatz für ein normgerechtes Messgerät. | Erste B2B-Lernhypothese: fachkundige Rückmeldung und bestehender projektbezogener Budgetrahmen sind plausibel, nicht nachgewiesen. |
| Betroffene Privatpersonen; Nutzer zahlen selbst | Belastende wiederkehrende Geräusche im eigenen Umfeld verständlich dokumentieren und eigene Beobachtungen ergänzen. | Papierprotokoll, kostenlose Apps, persönliche Hilfe; Ereignis kann vorübergehend sein, dauerhaftes Mikrofon und Fehlzuordnungen sind Hürden. | Stark für Mission und Reichweite; Kauf, Nutzungsdauer und Zugangskosten offen. |
| Betreiber eigener gewerblicher Standorte; Betriebs- oder Facility-Verantwortliche zahlen | Wiederkehrende auffällige Zeiten vor Ort eingrenzen, z. B. bei Beschwerden über Lieferungen oder Betriebsvorgänge. | Professionelle Anbieter, manuelle Ortsbegehung, vorhandene Betriebsdaten; Mikrofonaufstellung und Rechte Dritter. | Zweite B2B-Hypothese; nur konkret für einen Standort und einen klaren Entscheidungsablauf untersuchen. |
| Mietervereine, Initiativen, Kommunen und Forschung; Organisation oder Förderer zahlen | Gemeinsame Betrachtung von Ereignismustern und Beteiligung an lokalen Projekten. | Amtliche Karten, NoiseCapture, Messkampagnen; lange Beschaffung und methodischer Validierungsbedarf. | Besonders passend zur Vision, als bezahlter früher Vertrieb aber unbestätigt. |
| Wohnungsunternehmen; Verwaltung oder Eigentümer zahlen | Wiederkehrende Beschwerden strukturieren und Fälle nachvollziehbar bearbeiten. | Handprotokolle und bestehende Verwaltungssysteme; Machtasymmetrie, Vertrauen, Aufstellung in Wohnungen, Quellenzuordnung und Datenschutz. | Frühere Pro-Idee bleibt Option; vor einem Produktversprechen müssen die Risiken konkret gelöst werden. |
| Betreiber von Ferienwohnungen | Warnung vor wiederkehrendem Lärm und Einordnung für Gäste und Betreiber. | Etablierte Anbieter, Plattformregeln und besonders hohe Privatsphäre-Erwartung; Klassifikation geht möglicherweise über erlaubte Pegelmonitore hinaus. | Nicht erste Empfehlung. |

Es gibt bislang keine unabhängigen Interviews, beobachteten Arbeitsabläufe, Kaufzusagen oder Umsätze für die einzelnen Hypothesen. Insbesondere bedeutet ein existierender Markt nicht, dass Akustikbüros OpenNoiseNet benötigen oder für einen Wechsel bezahlen.

## Geschäftsmodelle im Vergleich

1. **Offene Software plus bezahlte Dienstleistung und Betrieb:** Quelloffener Kern und Selbstbetrieb bleiben zugänglich; bezahlt werden Einrichtung, laufender Betrieb, klar definierter Support und gegebenenfalls professionelle Auswertung. Plus: Nähe zur Mission und nachvollziehbares Nutzenversprechen. Risiko: personalintensiver Betrieb und begrenzte Skalierung.
2. **Offener Kern plus kostenpflichtige Pro-Ergänzungen:** Zugängliche Grundfunktionen, zusätzlich etwa Team-, Rollen- und Standortfunktionen. Das kann wiederkehrenden Umsatz ermöglichen, aber die Grenze zwischen Gemeingut und Bezahlprodukt muss fair, klar und mit Rechten aller Beitragenden vereinbar sein. Noch keine Festlegung, welche konkreten Teile geschlossen wären.
3. **Persönliche Nutzung mit Einmalzahlung oder freiwilliger Unterstützung:** Niedrige Einstiegshürde und Passung zu episodischen Problemen; laufender Support und Hosting müssen trotzdem finanziert werden. Ob jemand kauft oder spendet, ist unbekannt.
4. **Projektmittel, Forschung und gemeinnützige Partnerschaften:** Können offene Infrastruktur und Validierung tragen; abhängig von Förderfähigkeit und Projektlaufzeit, kein Ersatz für belastbare Finanzierung. Keine aktive Ausschreibung oder Förderzusage ist hier geprüft.
5. **Hardware oder SDK:** Denkbare spätere Erweiterungen. Hardware bringt Produktion, Gewährleistung und Logistik; eine SDK-Lizenz müsste gegen vorhandene Modelle und Anbieter bestehen. Beides ist nicht Voraussetzung für die erste Untersuchung.

Empfehlung als Arbeitshypothese: einen **offenen, dauerhaft nutzbaren Grundkern** mit **freiwillig bezahltem Betrieb und professionellen Leistungen** kombinieren. Weder Roh-Audio noch sensible standortbezogene Ereignisdaten als Finanzierungsquelle voraussetzen. Ein späteres Pro-Paket ist eine offene Produktentscheidung, keine automatische Einschränkung des bestehenden Repositories.

Das Repository enthält eine [MIT-Lizenz](../LICENSE), die kommerzielle Nutzung und Weitergabe unter Erhalt von Copyright- und Lizenzhinweis gestattet. Die Rechte an einzelnen Beiträgen, gebündeltem Modell, Labels, Bibliotheken, Marken und gegebenenfalls Datenbeständen sind separat zu inventarisieren. Aus der Repository-Lizenz allein folgt keine abschließende Freigabe für sämtliche Assets oder eine spätere Relizenzierung.

## Beispiel zur Wirtschaftlichkeit – ausdrücklich fiktiv

20 betreute Standorte à 29 € im Monat ergeben 580 € Monatsumsatz. Bei angenommenen 4 Supportstunden à 60 € und 60 € Infrastrukturkosten blieben 280 € vor Vertrieb, Entwicklung, Verwaltung, Steuern, Zahlungskosten und Ausfällen. Die Zahlen sind Rechenannahmen, keine gemessenen Kosten und kein vorgeschlagener verbindlicher Preis. Das Beispiel zeigt: Ein günstiges Abo trägt betreuungsintensive Kunden nicht automatisch.

Die Preise, Marktgrößen, Förderungen und Nutzungszusagen in der älteren [Business-Strategie](business-strategy.md) sind historische Planannahmen; einzelne Datenschutz- und Messversprechen dort sind durch den aktuellen Projektstand nicht belegt.

## Prüfvorschlag ohne Veröffentlichung oder Kontaktaufnahme

Erste Hypothese: **Kleine Akustikbüros begegnen wiederkehrenden Geräuschproblemen, bei denen eine nicht beweiskräftige Vorbeobachtung die Vorbereitung einer Fachmessung tatsächlich erleichtert.**

- Geeignete Teilnehmer wären sechs unabhängig ausgewählte Personen mit Verantwortung für solche Aufträge. Zuerst nach einem konkreten jüngeren Fall, dem bisherigen Vorgehen, Aufwand, Grenzen und Entscheidungen fragen; danach eine klar als vorläufig gekennzeichnete Demo zeigen. Keine echten Kundendaten ohne geeignete Grundlage erfassen.
- Vorab gesetzte, explorative Entscheidungshilfe: Bei mindestens drei konkret geschilderten relevanten Fällen samt tatsächlicher bisheriger Bearbeitung und mindestens einer ernsthaften Bereitschaft, nach Abschluss der Sicherheits- und Betriebsarbeiten einen bezahlten Test verbindlich zu vereinbaren, die Hypothese gezielt weiterverfolgen. Zwei Fälle oder nur unverbindliches Interesse: Eingrenzung und erneute Prüfung. Höchstens ein passender Fall: diese Zielgruppe zunächst zurückstellen. Die kleine Stichprobe ist nicht repräsentativ; eine Zusage ist noch kein bezahlter Auftrag.
- Ein echter bezahlter Test erfordert gesondert einen definierten Leistungsumfang, Daten- und Löschregeln, Rechte Dritter, Grenzen der Klassifikation und geklärte Betriebskosten. Die erforderlichen technischen und organisatorischen Grundlagen sind noch nicht vollständig; ein Pilot ist nicht beauftragt.
- Parallel kann das persönliche Lärmtagebuch gedanklich anhand derselben Fragen untersucht werden: konkrete Situation, jetzige Alternative, erwarteter Nutzen und Zahlungsform. Es braucht keine Produktänderung, um diese Fragen zu formulieren.

Risiken mit besonderer Tragweite: Fehlklassifikation und Identifizierung einer vermeintlichen Quelle, Überwachung Dritter, aus Zeit und Ort ableitbare personenbezogene Informationen, unzulässige Audioverarbeitung und missverständliche Aussagen zur Messgenauigkeit. Bei einem konkreten Einsatz sind die gesetzlichen und vertraglichen Anforderungen fachkundig zu prüfen; lokale Verarbeitung allein macht Daten nicht automatisch anonym oder rechtskonform.
