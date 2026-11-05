/// New raw-audio files remain disabled until encrypted recording and playback
/// have been implemented and verified. Existing recordings are not removed.
class AudioRecordingPolicy {
  static const bool newRecordingsAvailable = false;
  static const String unavailableMessage =
      'New audio recordings are temporarily unavailable until encrypted storage is ready.';

  static void requireNewRecordingsAvailable() {
    if (!newRecordingsAvailable) throw StateError(unavailableMessage);
  }
}
