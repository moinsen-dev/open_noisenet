/// Runtime health only: never send source labels, scores or classifications in
/// automatic heartbeats. Explicit event submission has its own existing policy.
Map<String, dynamic> publicSoundHealth(Map<String, dynamic> diagnostics) {
  const allowed = <String>{
    'initialized',
    'running',
    'model',
    'taxonomy_head',
    'input_sample_rate_hz',
    'inference_count',
    'dropped_windows',
    'audio_retention',
    'speech_recognition'
  };
  return Map.fromEntries(
      diagnostics.entries.where((entry) => allowed.contains(entry.key)));
}
