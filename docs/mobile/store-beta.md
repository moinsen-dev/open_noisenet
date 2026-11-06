# Interner Store-Test · OpenNoiseNet 0.1.0 (3)

Android: `dev.moinsen.noisenet_mobile`. iOS: `dev.moinsen.noisenetMobile`.
Getestet wird der reguläre Einstieg `lib/main.dart`. Feldtestpakete mit Suffix,
private Server, Gerätekennungen, Testkonfigurationen und Messdaten gehören nicht in Store-Builds.
Die Testversion startet ohne Backend. Der lokale Verlauf und das Tagebuch
funktionieren ohne Konto oder Standort. Für freiwillige Übertragungen muss
ein eigenes vertrauenswürdiges HTTPS-Ziel eingerichtet sein.
Der [Projektstand](../current-status.md) dokumentiert den tatsächlichen Verteilerstatus.

## Zugang für das Team

- **iOS** · In App Store Connect unter TestFlight die Gruppe **OpenNoiseNet intern** öffnen und die gewünschten internen Konten hinzufügen. Build **0.1.0 (3)** ist der Gruppe bereits zugeordnet. Die ausgewählten Personen öffnen die Einladung mit ihrem Apple-Konto in TestFlight.
- **Android** · In der Play Console unter **Internal testing → Testers** die eigenen Testkonten per E-Mail-Liste auswählen und speichern. Die ausgewählten Personen öffnen den Beitrittslink aus diesem Reiter mit demselben Google-Konto, das sie im Play Store verwenden.

Für die erste Runde hat Udi ein einziges Konto für beide Plattformen ausgewählt. Die direkten Teamlinks stehen im privaten Ideenkompass.

## Bauen und prüfen

Im Verzeichnis `mobile`: `flutter pub get --enforce-lockfile`, `dart run build_runner build`,
`flutter analyze`, `flutter test`. Beim Release-Bau die Flutter-Pluginliste für
Release neu generieren lassen (kein `--no-pub` nach Tests). Die Buildnummer
steht in `pubspec.yaml`; vor einem weiteren Upload mit dem jeweiligen Store abgleichen.

- **Google Play:** `NOISENET_ANDROID_SIGNING_PROPERTIES` auf den absoluten Pfad einer privaten Java-Properties-Datei setzen. Felder: `storeFile` (absolut), `keyAlias`, `storePassword`, `keyPassword`. Datei und Schlüssel außerhalb des Repositorys aufbewahren; ausschließlich den zugehörigen Upload-Schlüssel verwenden. `flutter build appbundle --release`. Mit `jarsigner -verify`, `bundletool validate` und `bundletool dump manifest` Paketname und Version prüfen. Eine aus diesem AAB erzeugte APK mit `scripts/check_android_16kb.py` prüfen; für den internen Track das signierte **AAB** verwenden.
- **TestFlight:** `flutter build ipa --release --export-options-plist=ios/ExportOptions-internal.plist`. Das Profil exportiert ausdrücklich für interne Tests und erhält die Buildnummer. IPA-Signatur, IDs und Modell prüfen, dann über App Store Connect hochladen. Apple-Verarbeitung, Verschlüsselungsangabe, Gruppenzuordnung und tatsächliche Installation getrennt verifizieren.
- Für den ersten Lauf nur interne Gruppen verwenden. Eine Store-Kontoerklärung,
  ein verarbeiteter Build und eine Installation sind verschiedene Nachweise.

## Was die Tester ausprobieren sollen

1. Mikrofon erlauben, Standort überspringen und das Monitoring starten. Lokale
   Historie aktivieren. Einige kurze Sätze mit Denkpausen sprechen, dann warten.
   In der Historie Anfang, Ende und mögliche Quelle vergleichen: Gab es einen
   zusammenhängenden Sprachblock? Quellen sind Modellhinweise; Pegel sind nicht geeicht.
2. Einen privaten Tagebucheintrag erstellen, App erneut öffnen, Eintrag prüfen und
   auf eigenen Wunsch exportieren. Den Export nur am selbst gewählten Ziel teilen.
   Es werden keine neuen Rohaufnahmen gespeichert.
3. Nur mit eigenem HTTPS-Testserver: Phasenupload getrennt aktivieren,
   Netz unterbrechen, wieder verbinden und quittierte Revisionen prüfen.
   Auf dem Server können andere Blockgrenzen gelten, weil die Freigabe später beginnt.
   Ohne Server ist dieser Schritt nicht Teil der lokalen Beta-Abnahme.

## Erklärungen vor der Verteilung

Die App schützt Tagebuch und Verlauf mit AES-GCM über das Dart-Paket
`cryptography` und verwahrt Schlüssel mit Plattformmitteln. Eine Erklärung
„ausschließlich Betriebssystem-Kryptografie“ lässt sich daraus nicht ableiten.
Keine personenbezogenen Feldtestdaten für Stores oder Support verwenden.
Die verbindlichen Export- und Richtlinienerklärungen gehören zum Kontoinhaber;
hier wird keine Freistellung behauptet.

Anbieter: [Interne TestFlight-Gruppen](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/),
[Apples Angaben zur Verschlüsselung](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/),
[interner Play-Test](https://support.google.com/googleplay/android-developer/answer/9845334).

## Public DACH candidate

Use the [release status](../current-status.md) for the current store build numbers and provider evidence. iOS review IPAs must be exported for **App Store**, not “TestFlight internal only”. Android version codes may advance independently. The Play bundle must declare only the foreground-service permissions the app actually uses. For the Android microphone declaration, demonstrate user-started monitoring, active notification while the main UI is backgrounded, and the user stopping monitoring. Use synthetic device data and a video with no audio track.

Self-hosters must upgrade the database with the included Alembic migrations before offering account creation/deletion. Make a verified backup first; do not stamp or reset someone else's database. Current builds check the versioned deletion capability before registration. A valid login and the current password are required to delete the account. A successful transaction removes associated devices, measurements, phases and derived records, revokes the old keys and tokens, and preserves other members' shared organization. Account-free sensors, separately exported copies, backup rotation and local diary deletion are separate operations. After confirmed in-app deletion the app switches to local mode; a retired device key must not be silently re-enrolled or used to replay queued data. Use the [isolated review runbook](../../infrastructure/store-review/README.md) for store credentials, not a field-test account.
