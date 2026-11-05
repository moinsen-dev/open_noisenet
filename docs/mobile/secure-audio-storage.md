# Secure audio storage: implementation boundary

New manual, continuous, and diagnostic recordings are temporarily disabled by
the mobile app until an encrypted end-to-end implementation has been built and
reviewed. Existing recordings are not deleted or migrated by this switch. The
pre-existing expiry and cleanup behavior is unchanged. Sensor operation and
ephemeral in-memory audio used for local inference remain available.

An isolated [synthetic experiment](../../experiments/secure_audio_poc/README.md)
exercises libsodium's streaming authentication for empty, partial and exact
chunk sizes, wrong keys, tampering, truncation, removal, duplication and
reordering on the Mac host; it does not encrypt recordings in the app. A
separate minimal Android release containing sodium 4.1.2+1 passed 16-KB
ZIP/native-library checks on ARM64 and x86_64 and initialized the library on
an ARM64 Android 17 16-KB emulator. That check did not exercise encryption or
audio on the emulator, or establish full-app/iOS compatibility.

## Required implementation

1. Capture PCM as a stream and encrypt before writing to persistent storage.
   Do not record a plaintext WAV first and encrypt it afterwards: a crash or
   process termination could leave the plaintext behind.
2. Use a reviewed authenticated streaming format such as libsodium
   [secretstream](https://doc.libsodium.org/secret-key_cryptography/secretstream),
   including a mandatory authenticated final marker. Reject corruption,
   truncation, reordering and wrong keys; never pass a partial recording off as
   complete. Any framing and associated metadata must be versioned and tested.
3. Generate independent cryptographic material with secure randomness and
   protect keys through the platform's secure storage. Specify behavior after
   app reinstall, device transfer, locked-device access, and key loss. Never
   persist keys in logs, the recording database or public event metadata.
4. Playback must decrypt only in memory or through an equivalently protected
   streaming path. Do not create unencrypted temporary playback files. Validate
   interruption, cancellation, partial-write recovery and bounded memory.
5. Maintain separate encrypted files and plaintext legacy files. Existing files
   require an explicit, recoverable migration procedure with integrity checks;
   do not delete them merely because encryption is enabled in a later build.
6. Preserve the agreed consent, recording duration and retention rules. Local
   timers alone do not establish deletion when the app remains stopped; define
   and test the actual platform guarantees and communicate their limits.
7. Verify Android and iOS builds, including native dependency provenance,
   Android 16-KB pages, background interruptions, physical-device playback,
   key availability and backup/restore behavior before re-enabling capture.

Android backup rules currently exclude the app's two recording directories
from cloud backup and device transfer. The compiled manifest and XML were
checked, but an actual platform backup/restore has not been exercised. These
rules do not encrypt the local files. iOS backup exclusion and app-level
encryption are still unimplemented; OS data protection depends on device
configuration. No existing audio was inspected or changed for this work.
