# Docker-/Backend-Wiederanlauf und Upload-Abgleich

Prüfung am 05.11.2026 gegen 16:18 CET. Udi autorisierte die Wiederherstellung des Backends bei unveränderter Pixel-App und unverändertem R2-Runner.

## Befund und Wiederanlauf

Der lokale OrbStack-VM-Log enthält um **15:13:00 CET** Schreibfehler `StorageFull`, OS-Code 28, `No space left on device`. Danach BTRFS-Schreibfehler, erzwungener Nur-Lese-Zustand und VM-Stopp. Damit ist voller Host-Speicher als unmittelbare Ausfallursache belegt; die einzelne Quelle des gesamten Speicherverbrauchs ist nicht bestimmt.

Beim Wiedereinstieg war Docker bereits zurück. Die vorhandenen Backend-, PostgreSQL- und Redis-Container starteten um **15:55:34 CET** und sind gesund; der erste gesunde Monitorstand liegt bei **15:56:23 CET**. VM-Start war etwa 15:55:30 CET. Der Auslöser dieses bereits erfolgten Wiederanlaufs ist nicht ermittelt. Es wurde **kein weiterer Neustart** ausgelöst. Context ausdrücklich `orbstack`; keine Migration auf den M1, keine Images/Volumes des Feldtests ersetzt. Vorhandene Restart-Policy ist `unless-stopped`.

Host hatte beim Wiedereinstieg rund 14 GiB frei. PostgreSQL meldete automatische Recovery nach unsauberem Ende und anschließend Bereitschaft; keine neuen ERROR/FATAL/PANIC-Meldungen im geprüften Wiederanlauf. Backend-Health ist erfolgreich, neue Geräte-Heartbeats und steigende Erfassungs-/Inferenzzähler zeigen wieder tatsächlichen Betrieb. Frischer logischer Datenbank-Dump samt lesbarem `pg_restore --list` privat gesichert; keine vollständige Restore-/Dateisystemprüfung behauptet.

## Ausstehende Übertragungen

Die berichtete Ereigniswarteschlange ist nach Wiederkehr leer. Vorhandene lokale Empfangsbestätigung passt exakt zur Server-UUID/-ID, ohne Abweichung oder Duplikat. Diese Bestätigung bestand bereits vor dem Ausfall; während der nicht erreichbaren Beobachtungen wurde kein unbestätigter lokaler Upload protokolliert.

**Keine beobachtete Nachlieferung nach diesem Ausfall**, weil keine wartende Sendung festgestellt wurde. Daraus folgt weder Datenverlust noch ein neu bestandener physischer Retry-Test. Die privaten Minutenmessungen sind kein Nachweis von Ereigniszustellung. Der neue Phasenupload aus PR #73 ist nicht auf dem Pixel installiert und wird durch diesen Betriebsabgleich nicht physisch validiert.

## Schutz und verbleibende Grenzen

- Keine App-Installation, keine Einstellungen, kein Sensor-/ADB-Neustart, keine Audio-Wiedergabe. Bestehender Runner und caffeinate aktiv; gleiche vorgesehene Deadline **06.11.2026 12:12:01 CET**. Vorhandene Monitorprotokolle zeigen keine PID-Änderung oder innere Minutenlücke, aber keine Garantie lückenlosen PCM-Empfangs.
- Hauptcheckout samt fremden Änderungen und `.pumuckl` erhalten. Keine Backend-Quelländerung, Migration oder öffentliche Veröffentlichung.
- Ausschließlich der eigene temporäre synthetische Container `onn-source-phase-qa-20261105` anhand ID und Eigentumslabel geprüft und entfernt. Keine Feldtest-/Fremdcontainer oder Volumes bereinigt. Die zuvor offene QA-Aufräumaufgabe ist damit erledigt.
- Ursache behoben im Sinne aktuell wieder verfügbarer Speicherkapazität und gesunder Dienste; Speicher kann durch parallele Arbeit erneut knapp werden. Keine Wiederholungsgarantie, kein 24h-Abschluss. Keine Änderung des Test-Monitors zur Ressourcenkontrolle.

Private Belege ausschließlich unter `~/Library/Application Support/OpenNoiseNet/Feldtest-2026-11-05-R2/backend-recovery-20261105T151723Z/`: begrenzter Fehlerauszug, Monitor-Snapshot, Audit, Datenbank-Dump und Dateihashprüfung. Keine persönlichen Messwerte, Gerätekennungen, Zugangsdaten oder Dateien in Git/Vault.
