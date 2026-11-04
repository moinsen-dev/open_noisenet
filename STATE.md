# OpenNoiseNet – Arbeitsübergabe

## Übergabe

**Auftrag abgeschlossen:** zentrale persönliche Geschichte auf der Website veröffentlicht; PR #69 und alle 58 offenen Issues abgeglichen.

- Website: https://opennoisenet.moinsen.dev/ und `/story/`; GitHub-Pages-Spiegel ebenfalls aktualisiert. Neue deutsche Geschichte, nachvollziehbare Entwicklungsgrenzen, Forschungsquellen, konkrete Mitwirkungsmöglichkeiten. `.pumuckl` ist unverändert als Projektdatei mitcommittet.
- PRs #70 (Website) und #69 (Dokumentation) gemergt. #51 erledigt; #5 → #66 und #47 → #52 als Doppelungen zusammengeführt, nicht als implementiert. **55 Issues offen, keine offenen PRs.**
- Lint, Typprüfung, Root-/Unterpfad-Build, 3 Consent-Tests, Desktop-/320-/390-px-Ansichten geprüft; produktive npm-Abhängigkeiten ohne bekannten Audit-Befund. GitHub-Pages-Deployment erfolgreich und im öffentlichen Browser geprüft.
- Custom-Domain: Origin und öffentliche HTTPS-Inhalte vom Server geprüft. Lokaler automatisierter Browser trifft Cloudflare-Challenge; keine Sicherheitsregeln dafür gelockert. Pixel-Test/App-Dienste nicht verändert.
- Maßgebliche Übersicht mit allen 58 Entscheidungen: [Website und GitHub-Abgleich](docs/website-story-and-github-review-2026-11-04.md). Hosting: [Landing deployment](docs/landing-deployment.md).
- **Getrennte technische Arbeit:** `codex/fieldtest-visual-20261104` hat 35 zusätzliche lokale Commits außerhalb von develop und keinen veröffentlichten Remote-Zweig. Vor einer technischen Gesamtrelease gezielt prüfen/integrieren. Nicht aus dem Website-Release auf den App-Stand schließen.
- Abschluss auf Klabauter-Hinweis: kein neuer großer Arbeitsschritt begonnen. Lokale Vorschau und eigene Browser-Testsession werden beendet; produktiver Webcontainer und Pixel-Test bleiben bestehen.
- Nächste technische Arbeit aus dem früheren Auftrag: Pixel-Test nach 24 Stunden separat auswerten, anschließend App-Integration und offene Qualitätsnachweise. Dieser Website-Block hat den laufenden Test nicht geprüft oder neu gestartet.
