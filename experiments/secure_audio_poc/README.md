# Secure audio stream experiment

This isolated, synthetic-only Dart experiment checks libsodium secretstream
round trips and rejection of corruption, truncation, reordering, removal,
duplication, and wrong keys. Run
`dart pub get` and `dart run bin/main.dart`. It writes no recordings and is
not imported by the mobile app. Keys are generated in memory for this test.

This is not an encrypted recording or playback implementation. In particular,
device key storage, app lifecycle, file handling, iOS builds, memory and
failure recovery remain to be validated. A separate minimal Android release
using sodium 4.1.2+1 passed static 16-KB checks on ARM64/x86_64; its ARM64
build initialized sodium on an Android 17 16-KB emulator. Encryption and audio
were not exercised on that emulator, nor was sodium integrated into the app. See
../../docs/mobile/secure-audio-storage.md before using this for real audio.
This experiment requires Dart 3.10 or newer; the mobile package currently
declares support for Dart 3.1 and does not depend on this experiment.
