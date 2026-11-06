# Interner Store-Test · OpenNoiseNet 0.1.0 (3)

Android: `dev.moinsen.noisenet_mobile`. iOS: `dev.moinsen.noisenetMobile`.
Getestet wird der reguläre Einstieg `lib/main.dart`. Feldtestpakete mit Suffix,
private Server, Gerätekennungen, Testkonfigurationen und Messdaten gehören nicht in Store-Builds.
Die Testversion startet ohne Backend. Der lokale Verlauf und das Tagebuch
funktionieren ohne Konto oder Standort. Für freiwillige Übertragungen muss
ein eigenes vertrauenswürdiges HTTPS-Ziel eingerichtet sein.
Der [Projektstand](../current-status.md) dokumentiert den tatsächlichen Verteilerstatus.

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
