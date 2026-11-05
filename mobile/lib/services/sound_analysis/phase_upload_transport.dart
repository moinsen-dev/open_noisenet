/// A queued phase is bound to one backend and device before any network work.
abstract class PhaseUploadTransport {
  String get baseUrl;
  String? get deviceId;
  Future<String> ensureDeviceId();
  Future<void> preparePhaseUpload(String destination, String device);
  Future<Map<String, dynamic>> putSourcePhase(String destination, String device,
      Map<String, dynamic> payload, bool Function() permitted);
  Future<Map<String, dynamic>> deleteSourcePhase(String destination,
      String device, String phaseId, bool Function() permitted);
}
