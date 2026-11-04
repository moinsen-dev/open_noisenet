# Zentrale Geschichte und GitHub-Abgleich – 4. November 2026

## Auftrag und Gesamtübersicht

Udi hat die Veröffentlichung der zentralen Geschichte auf der Website beauftragt. Die persönliche Motivation, Belastungen Betroffener und konkrete Unterstützungsmöglichkeiten bilden den roten Faden. Die breitere Suche nach Anwendungsfällen und Pilotpartnern bleibt offen.

1. Erledigt – Quellen, Website und GitHub-Iststand geprüft: 58 offene Issues, Dokumentations-PR #69.
2. Erledigt – deutsche Startseite und persönliche Geschichte umgesetzt, gebaut, im Browser geprüft und unter der Custom-Domain veröffentlicht.
3. Erledigt – beide PRs zusammengeführt; alle 58 Issues abgeglichen, #51 erledigt, #5/#47 als Doppelungen zusammengeführt. GitHub bestätigt 55 offene Issues und keine offenen PRs.

→ Abschluss: Website-/GitHub-Auftrag erledigt; Nachweise und Übergabe gesichert. Kein weiterer technischer Funktionsumfang aus den alten Issues automatisch beauftragt.

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

Inhalt veröffentlicht als Commit `a7ffd8c`, PR #70; nachträglich nur der Kontrast des Cookie-Hinweises verbessert (Release r2). Anschließend mit PR #69 in `develop` zusammengeführt (`99e008b`).

- Öffentliche Adresse: https://opennoisenet.moinsen.dev/ ; persönliche Geschichte: https://opennoisenet.moinsen.dev/story/ .
- Die Domain hatte zuvor keine eigene Ingress-Regel. Ergänzt wurde ausschließlich diese Domain → `http://localhost:18768` im vorhandenen gesunden Tunnel; alle zwölf bestehenden Ingress-Einträge blieben erhalten. Keine DNS-/Firewall-/Challenge-Regeln geändert.
- Statischer Export in `/opt/opennoisenet-site/releases/20261104-story-r2` auf dem bestehenden Hetzner-Server; Container `opennoisenet-site`, ausschließlich `127.0.0.1:18768`, read-only, 96 MB Limit. nginx-Konfiguration geprüft; kein App-/Backend-Prozess neu gestartet.
- Origin `/` und `/story/`: HTTP 200; Container ohne Neustart. Öffentliche HTTPS-Abrufe vom Server bestätigen Titel/Text von Startseite, Geschichte und Datenschutz sowie byteidentisches Icon. Cloudflare verändert HTML unter anderem durch E-Mail-Schutz; deshalb kein behaupteter identischer HTML-Hash.
- Lokaler automatisierter Browser und lokales curl erhalten weiterhin eine Cloudflare-Challenge (403), während reguläres curl vom Server die neue Seite erhält. Das ist eine dokumentierte Grenze der öffentlichen Browserprüfung, kein behaupteter vollständiger Besucher-Abnahmetest.
- GitHub Pages existiert separat unter `https://moinsen-dev.github.io/open_noisenet/` und hat keine Custom-Domain. Der neue Stand wurde dort über [Workflow 41833257939](https://github.com/moinsen-dev/open_noisenet/actions/runs/41833257939) erfolgreich veröffentlicht und anschließend im Browser mit korrekten Styles/Assets und Unterpfad-Navigation geöffnet.
- Rollback: Bei einer Folgeversion zunächst einen neuen Release-Ordner prüfen und erst dann das Web-Container-Mount umstellen. Diese erste neue Domain-Route kann gezielt entfernt werden, ohne andere Tunnel-Routen anzufassen. Tunnel-Konfiguration vor Änderung wurde privat gesichert (nicht im Repository).

Lokale Bildnachweise: [Desktop](../output/playwright/published-github-pages.png), [Mobil](../output/playwright/home-mobile.png), [Geschichte mobil](../output/playwright/story-mobile.png). Die hellen Consent-Texte wurden nach Sichtprüfung zusätzlich auf kontrastreiches Schiefergrau korrigiert.

## GitHub-Abgleich

Prüfbasis: öffentlicher `develop`-Stand `99e008b` sowie gezielte Gegenprüfung der getrennten lokalen Entwicklungsarbeit. Ein vorhandener Bildschirm, ein Paketname oder eine geplante Funktion erfüllt nicht automatisch alle Abnahmekriterien. Neue YAMNet-/Tagebuch-/Sicherheitsarbeit ist noch nicht vollständig in `develop`; dieser Website-Release hat das bewusst nicht geändert.

**Ergebnis:** 58 vorhandene Issues geprüft; 1 nachweislich erledigt (#51), 2 Doppelungen geschlossen (#5 → #66, #47 → #52), 55 bleiben offen. Doppelungen wurden als `not_planned` geschlossen, ausdrücklich nicht als implementiert. Anforderungen wurden im Ziel-Issue erhalten. Hardware bleibt wie zuvor pausiert, nicht verworfen.

PR #69: drei Dokumentationsdateien, +93/−10, keine Laufzeitänderung; relative Links, Sprachenkonventionen und Vorlage geprüft, GitGuardian erfolgreich. Gemergt; #51 automatisch geschlossen und seine erfüllten Kriterien nachgetragen. Website-PR #70 ebenfalls gemergt. Keine offenen PRs nach beiden Merges.

| Issue | Entscheidung | Beleg / noch fehlendes Kriterium |
|---|---|---|

| [#5](https://github.com/moinsen-dev/open_noisenet/issues/5) | Zusammengeführt → #66 | Gleicher Auth-Umfang; Profile, sicherer Tokenspeicher und Refresh bleiben im Ziel-Issue. |
| [#6](https://github.com/moinsen-dev/open_noisenet/issues/6) | Offen | Keine aktive mobile Kartenroute in `mobile/lib/core/router/app_router.dart`; Webkarte erfüllt dieses Mobile-Issue nicht. |
| [#7](https://github.com/moinsen-dev/open_noisenet/issues/7) | Teilweise | Tagebuch-Export in neuer Entwicklung ist nicht der geforderte vollständige Statistikexport in CSV/JSON mit Metadaten und Fortschritt. |
| [#8](https://github.com/moinsen-dev/open_noisenet/issues/8) | Teilweise | `settings_page.dart` enthält einen Offset-Dialog; vollständiger Assistent, Profile und Import/Export fehlen. Referenzton allein ist keine Kalibrierung. |
| [#10](https://github.com/moinsen-dev/open_noisenet/issues/10) | Offen | Keine FCM-Integration in mobilem Code/Abhängigkeiten; Foreground-Service-Mitteilung ersetzt keine Push-Kette. |
| [#11](https://github.com/moinsen-dev/open_noisenet/issues/11) | Teilweise | `noise_chart.dart` enthält fl_chart und Tooltips; vollständige fachlich korrekte Leitlinien-Einordnung nicht nachgewiesen. |
| [#12](https://github.com/moinsen-dev/open_noisenet/issues/12) | Integration offen | YAMNet in getrenntem Entwicklungszweig erprobt. In develop meldet `ai_analysis_service.dart` noch `hasAnalysisCapability => false`; Paketname allein genügt nicht. |
| [#13](https://github.com/moinsen-dev/open_noisenet/issues/13) | Teilweise | `endpoints/events.py` implementiert Aufnahme/Validierung. Erforderliche Geräteauthentifizierung ist in diesem develop-Stand noch nicht durchgängig gebunden. |
| [#14](https://github.com/moinsen-dev/open_noisenet/issues/14) | Teilweise | `endpoints/auth.py`: Register/Login/Refresh vorhanden; Reset und E-Mail-Verifikation fehlen. |
| [#15](https://github.com/moinsen-dev/open_noisenet/issues/15) | Integration offen | Geräteregistrierung vorhanden; geheime Geräteschlüssel und Übergang liegen in neuer Entwicklung, nicht im geprüften develop-Stand. |
| [#16](https://github.com/moinsen-dev/open_noisenet/issues/16) | Teilweise | Aggregations-Worker vorhanden; geforderte hourly/daily/trends-API mit Redis-Cache nicht als vollständige Oberfläche vorhanden. |
| [#17](https://github.com/moinsen-dev/open_noisenet/issues/17) | Offen | Kein Newsletter-Router in `api/v1/api.py`; Bestätigungs-/Abmeldedienst nicht implementiert. |
| [#18](https://github.com/moinsen-dev/open_noisenet/issues/18) | Offen | Kein vollständiger authentifizierter WebSocket-/Redis-PubSub-Pfad im aktuellen API-Router. |
| [#19](https://github.com/moinsen-dev/open_noisenet/issues/19) | Teilweise | Pro-Exports in `pro_incidents.py` vorhanden; generischer asynchroner Export mit Celery/Anonymisierung ist damit nicht vollständig erfüllt. |
| [#20](https://github.com/moinsen-dev/open_noisenet/issues/20) | Zurückgestellt | `endpoints/admin.py` antwortet ausdrücklich 501; kein abgeschlossener Admin-Bereich. |
| [#21](https://github.com/moinsen-dev/open_noisenet/issues/21) | Zurückgestellt | `endpoints/snippets.py` antwortet 501; neue Audioaufnahmen bleiben nach Udis Entscheidung bis zur sicheren Lösung pausiert. |
| [#22](https://github.com/moinsen-dev/open_noisenet/issues/22) | Teilweise | Nginx `limit_req` vorhanden; Redis-basierte Nutzerquoten und geforderte Erkennungs-/Alarmkette fehlen. |
| [#23](https://github.com/moinsen-dev/open_noisenet/issues/23) | Offen | `notification_tasks.py`: E-Mail-/Push-Versand ausdrücklich Platzhalter; Versandnachweise fehlen. |
| [#24](https://github.com/moinsen-dev/open_noisenet/issues/24) | Offen | `maintenance_tasks.py`: Cleanup zählt Platzhalterwerte 0; keine belegte tatsächliche Löschung. |
| [#25](https://github.com/moinsen-dev/open_noisenet/issues/25) | Teilweise | `MapPage.tsx`: Leaflet und Popups vorhanden; Heatmap, WebSocket und gesamter Filterumfang fehlen. |
| [#26](https://github.com/moinsen-dev/open_noisenet/issues/26) | Offen | `frontend/src/App.tsx` routet weder Login/Registrierung noch Passwort-Reset und Profiloberfläche. |
| [#27](https://github.com/moinsen-dev/open_noisenet/issues/27) | Teilweise | `DevicesPage.tsx`: Grundverwaltung vorhanden; gesamter Umfang mit bestätigtem Entfernen und Echtzeitstatus nicht belegt. |
| [#28](https://github.com/moinsen-dev/open_noisenet/issues/28) | Teilweise | Geräte-Timeline und Pro-Ansichten vorhanden; geforderte vollständige Analytics-Ansicht samt Diagrammbildexport fehlt. |
| [#29](https://github.com/moinsen-dev/open_noisenet/issues/29) | Offen | Kein gemeinsamer WebSocket-/Reconnect-/Offline-Pfad für Karte und Diagramme nachgewiesen. |
| [#30](https://github.com/moinsen-dev/open_noisenet/issues/30) | Offen | Profile, Kommentare, Forum, Rangliste und Abzeichen sind keine vorhandenen Dashboard-Routen. |
| [#31](https://github.com/moinsen-dev/open_noisenet/issues/31) | Teilweise | Responsive MUI-Struktur vorhanden. Neue Landing-Mobilprüfung ersetzt keine Prüfung aller Dashboard-Tabellen und Kartensteuerungen. |
| [#32](https://github.com/moinsen-dev/open_noisenet/issues/32) | Teilweise | Events/Inbox haben Filter; gespeicherte Suchen, Orts-Autocomplete und vollständiger Filterumfang fehlen. |
| [#33](https://github.com/moinsen-dev/open_noisenet/issues/33) | Zurückgestellt | `AdminPage.tsx` enthält TODO und ist keine freigegebene Verwaltung. |
| [#34](https://github.com/moinsen-dev/open_noisenet/issues/34) | Offen | Kein Service Worker/PWA-Manifest für das Dashboard; `mobile/web/manifest.json` gehört zu einer anderen Oberfläche. |
| [#35](https://github.com/moinsen-dev/open_noisenet/issues/35) | Offen / spätere Idee | Neue Website verwendet Kontaktlinks; kein behauptetes Newsletter-Formular. Backend #17 fehlt. |
| [#36](https://github.com/moinsen-dev/open_noisenet/issues/36) | Offen | Keine Landing-Routen `/confirm-email` oder `/unsubscribe`; Backend-Kette fehlt. |
| [#37](https://github.com/moinsen-dev/open_noisenet/issues/37) | Offen / spätere Idee | Die persönliche Story ist kein Blog mit Artikelliste, Tags und verwandten Beiträgen. |
| [#38](https://github.com/moinsen-dev/open_noisenet/issues/38) | Teilweise | Deutsche Start-/Story-Seite ist keine EN/DE/ES/FR-Lokalisierung mit Sprachumschalter und Locale-Routing. |
| [#40](https://github.com/moinsen-dev/open_noisenet/issues/40) | Offen | Kein verifizierter allgemeiner Store-Download; daher keine irreführenden Download-Badges. |
| [#41](https://github.com/moinsen-dev/open_noisenet/issues/41) | Teilweise | Ein Landing-Deploy-Workflow existiert; vollständige Test-/Build-CI für Backend, Dashboard und Mobile sowie Staging fehlen. |
| [#42](https://github.com/moinsen-dev/open_noisenet/issues/42) | Teilweise | Compose/Umgebung/Proxy-Dokumente vorhanden; statische Website-Veröffentlichung bestätigt keinen produktionsreifen Gesamtstack oder Restore. |
| [#43](https://github.com/moinsen-dev/open_noisenet/issues/43) | Teilweise | Prometheus/Grafana-Konfigurationen vorhanden; vollständige ELK/Sentry/Alarmkette nicht belegt. |
| [#44](https://github.com/moinsen-dev/open_noisenet/issues/44) | Offen | Keine nachgewiesene automatische Backup-/Restore-Kette mit Übung, Retention und Alarmen. |
| [#45](https://github.com/moinsen-dev/open_noisenet/issues/45) | Teilweise | Website jetzt über Cloudflare; die geforderten Bildoptimierungen/WebP und weltweiten Performance-Nachweise sind nicht vollständig erfüllt. |
| [#46](https://github.com/moinsen-dev/open_noisenet/issues/46) | Offen | Privater Testzugang ist keine automatisch aus develop bereitgestellte Staging-Umgebung mit eigener Datenbank. |
| [#47](https://github.com/moinsen-dev/open_noisenet/issues/47) | Zusammengeführt → #52 | Überlappende Deployment-Dokumentation; zusätzliche Restore-/Tuning-/Hardening-Kriterien nach #52 übernommen. |
| [#48](https://github.com/moinsen-dev/open_noisenet/issues/48) | Teilweise | FastAPI/OpenAPI vorhanden; vollständige Endpunktbeispiele und Postman-Sammlung fehlen. |
| [#49](https://github.com/moinsen-dev/open_noisenet/issues/49) | Teilweise | Entwicklungsnotizen/Prüfbilder vorhanden; kein umfassend verifizierter Nutzerleitfaden zu allen aktuellen Funktionen und Exporten. |
| [#50](https://github.com/moinsen-dev/open_noisenet/issues/50) | Pausiert | Hardware-Bauanleitung benötigt reale Firmware, Schaltplan/Gehäuse und Kalibrierbelege; abhängig von #59–61. |
| [#51](https://github.com/moinsen-dev/open_noisenet/issues/51) | Erledigt | PR #69 erfüllt CONTRIBUTING, Sprachenkonventionen, Setup, Branch-/Issue-Ablauf und PR-Vorlage. |
| [#52](https://github.com/moinsen-dev/open_noisenet/issues/52) | Teilweise | `infrastructure/DEPLOYMENT.md` bietet Compose/Umgebungs-/TLS-Schritte; Bare-metal und geprüfte Recovery-Verfahren bleiben offen. #47 integriert. |
| [#55](https://github.com/moinsen-dev/open_noisenet/issues/55) | Teilweise / Sammelziel | Karte/Geräte vorhanden; Auth-UI, Newsletter und Echtzeitkette fehlen. Keine pauschale Phasenabnahme. |
| [#56](https://github.com/moinsen-dev/open_noisenet/issues/56) | Offen / Sammelziel | Funktionsgleichheit, Flottenbetrieb, verschiedene Gerätegenerationen und mehrtägiger Betrieb sind nicht belegt. |
| [#57](https://github.com/moinsen-dev/open_noisenet/issues/57) | Teilweise / Sammelziel | Klassifikationsversuche und Auswertung existieren; >80% Klassifikationsgüte, Lastverhalten und gesamte Echtzeitkette nicht nachgewiesen. |
| [#58](https://github.com/moinsen-dev/open_noisenet/issues/58) | Offen / Sammelziel | 10.000 Nutzer, 1.000 Sensoren, 99,9% Verfügbarkeit, 50 Mitwirkende und Betriebsnachweise sind Zielwerte, keine Ergebnisse. |
| [#59](https://github.com/moinsen-dev/open_noisenet/issues/59) | Pausiert | ESP32-Firmware ist ausdrücklich ON HOLD; kein Anlass, sie als erledigt oder endgültig verworfen zu schließen. |
| [#60](https://github.com/moinsen-dev/open_noisenet/issues/60) | Pausiert | Raspberry-Pi-Variante ausdrücklich ON HOLD. |
| [#61](https://github.com/moinsen-dev/open_noisenet/issues/61) | Pausiert | Gehäuseentwicklung ausdrücklich ON HOLD. |
| [#62](https://github.com/moinsen-dev/open_noisenet/issues/62) | Teilweise | Smartphone-Sensor vorhanden. 24 Stunden auf einer Akkuladung, geräteübergreifende Kalibrierung und Adoptionserfolg unbestätigt. |
| [#63](https://github.com/moinsen-dev/open_noisenet/issues/63) | Offen | Kein validierter mehrsprachiger Altgeräte-Leitfaden; geforderte Erfolgsquote und Community-Nachweise fehlen. |
| [#65](https://github.com/moinsen-dev/open_noisenet/issues/65) | In Prüfung | Pixel-Test läuft separat. Netzbetrieb und ein einzelner Lauf belegen weder 24h Akkubetrieb noch Crash-/iOS-Festigkeit und <1% Verlust. |
| [#66](https://github.com/moinsen-dev/open_noisenet/issues/66) | Teilweise | Login/Register vorhanden. develop speichert Tokens noch in SharedPreferences; gesicherter Gesamtablauf und erweiterte Kriterien offen. #5 integriert. |
| [#67](https://github.com/moinsen-dev/open_noisenet/issues/67) | In Prüfung | A-Filter-/Kalibrierarbeiten laufen getrennt. ±3 dB über Geräte und Vergleich mit Referenzgerät sind nicht belegt. |

### Nächste sinnvolle technische Reihenfolge (kein neuer Vollumsetzungsauftrag)

1. Den laufenden Pixel-Test separat abschließen und seine Grenzen dokumentieren.
2. Bereits erarbeitete App-/Backend-Sicherheits-, YAMNet- und Historienänderungen kontrolliert mit develop zusammenführen; dafür einen eigenen technischen Review nutzen.
3. Kalibrierung/A-Bewertung und sichere Datenaufbewahrung fertig prüfen.
4. Alte Sammelziele und optionale Ausbauwünsche bei einer eigenen Planung auf die aktuelle Vision zuschneiden. Sie werden heute weder stillschweigend gestrichen noch als Lieferzusagen übernommen.

### Integrationsgrenze

Am Ende dieses Abgleichs liegt `codex/fieldtest-visual-20261104` mit 35 zusätzlichen Commits außerhalb von develop. Dieser lokale Zweig hat keinen veröffentlichten Remote-Zweig. Seine App-/Backend-Arbeiten und privaten Prüfbelege wurden nicht stillschweigend mit dem öffentlichen Website-Release vermischt. Die Issues #12/#13/#15/#65/#67 bleiben deshalb ausdrücklich offen; vor einer technischen Gesamtrelease sind Inhaltsprüfung, Integration und die jeweiligen Tests erforderlich.
