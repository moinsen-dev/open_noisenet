import 'package:sodium/sodium.dart';

Future<void> main() async {
  final sodium = await SodiumInit.init();
  final secretStream = sodium.crypto.secretStream;
  final key = secretStream.keygen();
  final wrongKey = secretStream.keygen();
  const chunkSize = 1024;

  Future<List<int>> encrypt(List<int> data) async =>
      Stream<List<int>>.fromIterable([data])
          .transform(
            secretStream.createPushChunked(key: key, chunkSize: chunkSize),
          )
          .expand((chunk) => chunk)
          .toList();
  Future<List<int>> decrypt(List<int> data, SecureKey useKey) async =>
      Stream<List<int>>.fromIterable([data])
          .transform(
            secretStream.createPullChunked(
              key: useKey,
              chunkSize: chunkSize,
              requireFinalized: true,
            ),
          )
          .expand((chunk) => chunk)
          .toList();
  Future<void> mustReject(
    List<int> data,
    SecureKey useKey,
    String reason,
  ) async {
    var rejected = false;
    try {
      await decrypt(data, useKey);
    } catch (_) {
      rejected = true;
    }
    if (!rejected) throw StateError('Failed to reject $reason');
  }

  try {
    for (final length in [0, 1, 1024, 2048, 4097]) {
      final data = List<int>.generate(length, (i) => i % 251);
      final ciphertext = await encrypt(data);
      final recovered = await decrypt(ciphertext, key);
      if (recovered.length != data.length ||
          !Iterable<int>.generate(
            data.length,
          ).every((i) => recovered[i] == data[i])) {
        throw StateError('Round-trip mismatch at $length bytes');
      }
      await mustReject(
        ciphertext.sublist(0, ciphertext.length - 1),
        key,
        'truncation',
      );
      await mustReject(ciphertext, wrongKey, 'wrong key');
      if (length > 0) {
        final tampered = List<int>.of(ciphertext)..[ciphertext.length - 2] ^= 1;
        await mustReject(tampered, key, 'tampering');
      }
      if (length >= 2048) {
        final header = secretStream.headerBytes;
        final packet = chunkSize + secretStream.aBytes;
        final prefix = ciphertext.sublist(0, header);
        final first = ciphertext.sublist(header, header + packet);
        final second = ciphertext.sublist(header + packet, header + 2 * packet);
        final tail = ciphertext.sublist(header + 2 * packet);
        await mustReject(
          [...prefix, ...second, ...first, ...tail],
          key,
          'reordering',
        );
        await mustReject([...prefix, ...second, ...tail], key, 'removal');
        await mustReject(
          [...prefix, ...first, ...first, ...second, ...tail],
          key,
          'duplication',
        );
      }
    }
    print('Synthetic streaming integrity checks: passed');
  } finally {
    key.dispose();
    wrongKey.dispose();
  }
}
