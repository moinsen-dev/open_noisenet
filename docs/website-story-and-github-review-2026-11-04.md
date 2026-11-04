# Zentrale Geschichte und GitHub-Abgleich – 4. November 2026

## Auftrag und Gesamtübersicht

Udi hat die Veröffentlichung der zentralen Geschichte auf der Website beauftragt. Die persönliche Motivation, Belastungen Betroffener und konkrete Unterstützungsmöglichkeiten bilden den roten Faden. Die breitere Suche nach Anwendungsfällen und Pilotpartnern bleibt offen.

1. Erledigt – Quellen, Website und GitHub-Iststand geprüft: 58 offene Issues, Dokumentations-PR #69.
2. → Aktuell – deutsche Startseite und persönliche Geschichte umgesetzt, statischer Build und kleine Mobilansichten geprüft; Veröffentlichung wird vorbereitet.
3. Offen – PR und jedes Issue anhand seiner Abnahmekriterien bewerten; nur belegbar Erledigtes schließen.

Diese Übersicht führt ausschließlich den Website-/GitHub-Auftrag. Der Pixel-Dauertest und laufende App-Arbeiten werden nicht verändert.

## Inhaltliche Leitplanken

- **Udis persönliche Angaben:** Lärm belästigt und stresst ihn; Hamburger Straßen machen für ihn die Lebensbedingungen der Anwohner sichtbar; Beschäftigung mit dem Projekt seit rund anderthalb Jahren; Geräuscherkennung im Entwicklungsversuch beeindruckt ihn.
- **Öffentlich belegt:** [UBA – Lärmbelästigung](https://www.umweltbundesamt.de/themen/laerm/laermwirkungen/laermbelaestigung), [EEA – Environmental noise in Europe 2025, korrigiert März 2026](https://www.eea.europa.eu/en/analysis/publications/environmental-noise-in-europe-2025). Forschung zu Bevölkerungsbelastungen ist keine Aussage über eine einzelne Wohnung oder Messung.
- **Zielbild:** zusammenhängende Episoden, Dauer, geschätzter Pegel, mögliche Ursachen, Ruhezeiten und Datenlücken; keine Täterzuordnung.
- **Offene Validierung:** Kalibrierung, Dauerbetrieb, Datenschutz. Keine zertifizierten dB(A)-Werte, keine medizinische oder rechtliche Beweiszusage, kein allgemeiner App-Download.
- **Unterstützung:** Erfahrungen, Code/Tests, Akustik und Referenzmessungen, Erprobung und Partnerschaften. Keine erfundenen Partner, Spendenbescheinigungen oder Sponsorenzusagen.
- Private Einträge werden nicht durch die Open-Source-Lizenz zu öffentlichen Daten. Die Timeline ist explizit illustrativ.

## Prüfung

- `npm ci`, `npm run lint`, `npm run type-check`, `npm run build`: erfolgreich.
- Bestehende Consent-Tests: 3 bestanden; notwendige Auswahl schaltet Analytics, funktionale und Marketing-Cookies aus.
- `npm audit --omit=dev`: 0 bekannte Schwachstellen; vollständiger Entwicklungsbaum meldet 16 moderate Befunde, nicht als behoben dargestellt.
- Browser: Startseite 1440 px und 390/320 px; Geschichte 320 px; kein horizontaler Überlauf. Erstbesuch bleibt auf Startseite, keine erzwungene Story-Weiterleitung.
- Keine externen Schriftarten, Beispielmessdaten oder persönlichen Aufnahmen geladen. Links zu E-Mail und GitHub; keine Nachricht versandt.
- Website basiert gezielt auf `origin/develop` plus bereits erarbeiteten Landing-Abhängigkeits-/Datenschutzkorrekturen. Die übrigen 35 lokalen App-/Backend-Commits werden durch diesen Release nicht implizit veröffentlicht.

## Veröffentlichung

In Vorbereitung. Die Domain hatte am 4. November keine eigene Ingress-Regel im bestehenden gesunden Cloudflare-Tunnel. GitHub Pages existiert separat unter `https://moinsen-dev.github.io/open_noisenet/` und hat keine Custom-Domain.

## GitHub-Abgleich

Noch in Bearbeitung. Ein vorhandener Bildschirm oder ein geplanter Punkt erfüllt nicht automatisch alle Abnahmekriterien eines Issues.
